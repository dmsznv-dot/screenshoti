import Foundation
import CoreGraphics
import Vision

struct DetectedTextRegion: Sendable {
    let text: String
    let normalizedTopLeftRect: CGRect
    let isSensitive: Bool
}
struct OCRResult: Sendable {
    let fullText: String
    let regions: [DetectedTextRegion]
}
actor VisionOCRAndRedactService {
    static let shared = VisionOCRAndRedactService()
    func analyzeImage(_ image: CGImage) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ru-RU", "en-US"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let regions = (request.results ?? []).compactMap { observation -> DetectedTextRegion? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return DetectedTextRegion(text: candidate.string,
                normalizedTopLeftRect: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height),
                isSensitive: Self.containsSensitiveInfo(candidate.string))
        }
        return OCRResult(fullText: regions.map(\.text).joined(separator: "\n"), regions: regions)
    }
    nonisolated static func containsSensitiveInfo(_ text: String) -> Bool {
        let patterns = [
            #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}"#,
            #"(?:\d[ -]*?){13,19}"#,
            #"\+?\d[\d\s\-\(\)]{8,18}\d"#,
            #"(?:sk-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9_]{12,}|Bearer\s+[A-Za-z0-9._-]+)"#,
            #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#
        ]
        return patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }
}
