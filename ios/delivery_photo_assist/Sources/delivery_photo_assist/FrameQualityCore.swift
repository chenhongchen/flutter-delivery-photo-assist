// Delivery demo extension. Same metric definitions as FrameQualityCore.kt.
import Foundation

enum FrameQualityCore {
  static func metrics(_ luma: [Double], width: Int, height: Int,
                      sourceWidth: Int, sourceHeight: Int) -> [String: Any] {
    guard width >= 16, height >= 16, luma.count == width * height else { return [:] }
    var sum = 0.0, sum2 = 0.0, lapSum = 0.0, lap2 = 0.0
    var dark = 0, clipped = 0, edges = 0, count = 0
    for y in 1..<(height - 1) {
      for x in 1..<(width - 1) {
        let i = y * width + x, c = luma[i]
        let lap = luma[i-1] + luma[i+1] + luma[i-width] + luma[i+width] - 4*c
        let gradient = abs(luma[i+1] - luma[i-1]) + abs(luma[i+width] - luma[i-width])
        sum += c; sum2 += c*c; lapSum += lap; lap2 += lap*lap
        if c < 25 { dark += 1 }; if c > 245 { clipped += 1 }
        if gradient > 12 { edges += 1 }; count += 1
      }
    }
    let n = Double(count), mean = sum/n
    return ["laplacianVariance": max(0, lap2/n - pow(lapSum/n,2)),
            "contrastStd": sqrt(max(0,sum2/n-mean*mean)), "meanLuma": mean,
            "darkFraction": Double(dark)/n, "clippedFraction": Double(clipped)/n,
            "edgeFraction": Double(edges)/n, "analysisWidth": width, "analysisHeight": height,
            "sourceWidth": sourceWidth, "sourceHeight": sourceHeight]
  }

  /// Four-point area sampling; never upscale a low-resolution source.
  static func sample(width: Int, height: Int, region: CGRect,
                     pixel: (Int,Int)->Double) -> [String: Any] {
    let frame = CGRect(x:0,y:0,width:width,height:height)
    let r = region.intersection(frame)
    guard !r.isNull, r.width >= 24, r.height >= 24 else { return [:] }
    let scale = min(1.0, 320.0/max(r.width,r.height))
    let w = max(16,Int(r.width*scale)), h = max(16,Int(r.height*scale))
    let dx = r.width/Double(w), dy = r.height/Double(h)
    var luma = [Double](repeating:0,count:w*h)
    for y in 0..<h { for x in 0..<w {
      let x0 = min(width-1,max(0,Int(r.minX+(Double(x)+0.25)*dx)))
      let x1 = min(width-1,max(0,Int(r.minX+(Double(x)+0.75)*dx)))
      let y0 = min(height-1,max(0,Int(r.minY+(Double(y)+0.25)*dy)))
      let y1 = min(height-1,max(0,Int(r.minY+(Double(y)+0.75)*dy)))
      luma[y*w+x] = (pixel(x0,y0)+pixel(x1,y0)+pixel(x0,y1)+pixel(x1,y1))/4
    }}
    return metrics(luma,width:w,height:h,sourceWidth:Int(r.width),sourceHeight:Int(r.height))
  }
}
