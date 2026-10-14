import AppKit
import Vision

struct DetectedTextRegion {
    let text: String
    /// Нормализованный прямоугольник в системе координат SwiftUI (сверху-слева 0,0)
    let normalizedTopLeftRect: CGRect
    let isSensitive: Bool
}

final class VisionOCRAndRedactService {
    static let shared = VisionOCRAndRedactService()
    
    /// Распознавание текста (RU + EN) и поиск конфиденциальных данных (Email, карты, телефоны, ключи)
    func analyzeImage(_ image: NSImage) async -> (fullText: String, regions: [DetectedTextRegion]) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ("", [])
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ("", []))
                    return
                }
                
                var lines: [String] = []
                var regions: [DetectedTextRegion] = []
                
                for obs in observations {
                    guard let topCandidate = obs.topCandidates(1).first else { continue }
                    let str = topCandidate.string
                    lines.append(str)
                    
                    let box = obs.boundingBox
                    // Перевод из координат Vision (снизу-слева) в координаты верхнего-левого угла
                    let topLeftRect = CGRect(
                        x: box.origin.x,
                        y: 1.0 - box.origin.y - box.height,
                        width: box.width,
                        height: box.height
                    )
                    
                    let sensitive = Self.containsSensitiveInfo(str)
                    regions.append(DetectedTextRegion(
                        text: str,
                        normalizedTopLeftRect: topLeftRect,
                        isSensitive: sensitive
                    ))
                }
                
                continuation.resume(returning: (lines.joined(separator: "\n"), regions))
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ru-RU", "en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: ("", []))
            }
        }
    }
    
    /// Проверка строки на наличие чувствительных данных (Email, телефоны, банковские карты, токены)
    private static func containsSensitiveInfo(_ text: String) -> Bool {
        let patterns = [
            "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}", // Email
            "(?:\\d[ -]*?){13,16}",                               // Банковские карты
            "\\+?\\d[\\d\\s\\-\\(\\)]{8,16}\\d",     // Телефоны
            "(sk-[A-Za-z0-9]{12,}|ghp_[A-Za-z0-9]{12,}|Bearer\\s+[A-Za-z0-9._-]+)" // API ключи
        ]
        
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}
