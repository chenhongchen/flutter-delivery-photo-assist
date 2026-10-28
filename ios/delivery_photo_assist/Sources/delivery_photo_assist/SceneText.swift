import Foundation
import Vision
import CoreImage
import CoreVideo
import ImageIO
import QuartzCore

/// OCR supplies possible visual clues, never a verified address or compliance verdict.
enum SceneText {
  static func image(_ image: CGImage, excluding parcels: [CGRect] = []) -> [String: Any] {
    let start = CACurrentMediaTime()
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US", "zh-Hans"]
    request.usesLanguageCorrection = false
    request.minimumTextHeight = 0.012
    do {
      try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
      let lines = (request.results ?? []).compactMap { observation -> [String: Any]? in
        guard let text = observation.topCandidates(1).first, text.confidence >= 0.45 else { return nil }
        let value = text.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let branding = value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US")).uppercased().filter { $0.isLetter || $0.isNumber }
        guard branding != "UMALL" else { return nil }
        let r = observation.boundingBox
        let box = CGRect(x: r.minX, y: 1-r.maxY, width: r.width, height: r.height)
        guard value.count <= 32, value.count >= 2 || (value.count == 1 && value.first?.isNumber == true), box.height >= 0.012 else { return nil }
        // Package branding is not a location clue.
        if parcels.contains(where: { p in
          let overlap = box.intersection(p)
          return !overlap.isNull && overlap.width*overlap.height > box.width*box.height*0.5
        }) { return nil }
        return ["text": value, "confidence": text.confidence,
                "box": [box.minX, box.minY, box.maxX, box.maxY]]
      }
      return ["lines": Array(lines.prefix(24)), "processingMs": (CACurrentMediaTime()-start)*1000,
              "scope": "possible_text_clues; not verified location", "status": "available"]
    } catch {
      return ["lines": [], "status": "unavailable"]
    }
  }

  static func jpeg(_ bytes: Data) -> [String: Any] {
    guard let source = CGImageSourceCreateWithData(bytes as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 1024
      ] as CFDictionary) else { return ["lines": [], "status": "unavailable"] }
    return self.image(image)
  }
}
