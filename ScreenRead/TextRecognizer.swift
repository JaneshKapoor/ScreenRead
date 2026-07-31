import CoreGraphics
import Vision

enum TextRecognizer {
    /// Runs on-device OCR and rebuilds the reading order of the snippet.
    ///
    /// Vision returns observations in no guaranteed order, so fragments are
    /// re-sorted top-to-bottom and grouped into lines using the median glyph
    /// height as the row tolerance — otherwise a two-column snippet comes back
    /// interleaved.
    static func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLanguages = ["en-US"]
        if let supported = try? request.supportedRecognitionLanguages(), !supported.isEmpty {
            request.recognitionLanguages = supported
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let fragments: [(box: CGRect, text: String)] = (request.results ?? []).compactMap {
            guard let candidate = $0.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return ($0.boundingBox, text)
        }

        guard !fragments.isEmpty else { return "" }

        return assembleLines(from: fragments)
    }

    private static func assembleLines(from fragments: [(box: CGRect, text: String)]) -> String {
        let heights = fragments.map(\.box.height).sorted()
        let medianHeight = heights[heights.count / 2]
        // Fragments whose centres sit within half a glyph height belong to the same row.
        let rowTolerance = max(medianHeight * 0.5, 0.005)

        // Vision's normalized space has a bottom-left origin, so descending midY
        // walks the snippet from top to bottom.
        let sorted = fragments.sorted { lhs, rhs in
            if abs(lhs.box.midY - rhs.box.midY) > rowTolerance {
                return lhs.box.midY > rhs.box.midY
            }
            return lhs.box.minX < rhs.box.minX
        }

        var lines: [String] = []
        var currentRow: [(box: CGRect, text: String)] = []

        for fragment in sorted {
            if let anchor = currentRow.first, abs(anchor.box.midY - fragment.box.midY) > rowTolerance {
                lines.append(currentRow.map(\.text).joined(separator: " "))
                currentRow = []
            }
            currentRow.append(fragment)
        }
        if !currentRow.isEmpty {
            lines.append(currentRow.map(\.text).joined(separator: " "))
        }

        return lines.joined(separator: "\n")
    }
}
