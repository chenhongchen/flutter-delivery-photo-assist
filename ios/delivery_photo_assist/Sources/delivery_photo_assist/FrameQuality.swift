import CoreVideo
import ImageIO
import Foundation
import CoreGraphics
import QuartzCore

enum FrameQuality {
  static func normalizeImported(_ data: Data) -> Data? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 4096]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return output as Data
  }
  static let parcelLabels: Set<String> = ["Box","Plastic bag","Handbag","Luggage and bags",
    "cardboard box","plastic bag","shopping bag","paper bag","delivery package","insulated delivery bag"]

  static func analyze(width:Int,height:Int,packageRect:CGRect?,pixel:(Int,Int)->Double) -> [String:Any] {
    let start = CACurrentMediaTime()
    let full = CGRect(x:0,y:0,width:width,height:height)
    var result: [String:Any] = ["global": FrameQualityCore.sample(width:width,height:height,region:full,pixel:pixel)]
    if let n = packageRect {
      let roi = CGRect(x:n.minX*Double(width),y:n.minY*Double(height),width:n.width*Double(width),height:n.height*Double(height))
      let metrics = FrameQualityCore.sample(width:width,height:height,region:roi,pixel:pixel)
      if !metrics.isEmpty { result["package"] = metrics }
    }
    result["processingMs"] = (CACurrentMediaTime()-start)*1000
    result["sourceWidth"] = width; result["sourceHeight"] = height
    return result
  }

  static func buffer(_ buffer:CVPixelBuffer,packageRect:CGRect?) -> [String:Any] {
    guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA else { return [:] }
    CVPixelBufferLockBaseAddress(buffer,.readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer,.readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to:UInt8.self) else { return [:] }
    let width=CVPixelBufferGetWidth(buffer),height=CVPixelBufferGetHeight(buffer),stride=CVPixelBufferGetBytesPerRow(buffer)
    return analyze(width:width,height:height,packageRect:packageRect) { x,y in
      let p = base.advanced(by:y*stride+x*4)
      return Double(77*Int(p[2])+150*Int(p[1])+29*Int(p[0]))/256
    }
  }

  static func jpeg(_ data:Data,packageRect:CGRect?,previewAspect:Double?) -> [String:Any] {
    let start=CACurrentMediaTime()
    guard let source=CGImageSourceCreateWithData(data as CFData,nil),
          let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any] else { return [:] }
    let rawW=(properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
    let rawH=(properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
    let orientation=(properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    let rotated=[5,6,7,8].contains(orientation)
    let actualW=rotated ? rawH:rawW,actualH=rotated ? rawW:rawH
    let options:[CFString:Any] = [kCGImageSourceCreateThumbnailFromImageAlways:true,
      kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:960]
    guard let image=CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary) else { return [:] }
    let w=image.width,h=image.height,stride=w*4
    var rgba=[UInt8](repeating:0,count:stride*h)
    var packet:[String:Any]=[:]
    rgba.withUnsafeMutableBytes { memory in
      guard let ctx=CGContext(data:memory.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:stride,
        space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
      // CGContext raster bytes are top-to-bottom in the same orientation as the thumbnail.
      ctx.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
      let bytes=memory.baseAddress!.assumingMemoryBound(to:UInt8.self)
      let sameAspect=previewAspect.map { abs($0-Double(w)/Double(h)) < 0.03 } ?? true
      packet=analyze(width:w,height:h,packageRect:sameAspect ? packageRect:nil) { x,y in
        let p=bytes.advanced(by:y*stride+x*4)
        return Double(77*Int(p[0])+150*Int(p[1])+29*Int(p[2]))/256
      }
      if !sameAspect { packet["packageCheck"]="unavailable_aspect_mismatch" }
    }
    packet["photoWidth"]=actualW;packet["photoHeight"]=actualH
    packet["processingMs"]=(CACurrentMediaTime()-start)*1000
    packet["scope"]="saved_jpeg; package ROI from latest preview, not re-detection"
    return packet
  }
}
