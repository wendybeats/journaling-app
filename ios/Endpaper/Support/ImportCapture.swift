// Import capture — writing that arrives from outside the keyboard:
// a photograph of a handwritten or printed page, or a file. Everything
// runs on-device (Vision OCR, PDFKit); nothing leaves the phone, same
// promise as voice.
//
// Photos → Vision text recognition, with paragraph reconstruction: lines
// that sit close together join into one flowing paragraph; a larger
// vertical gap starts a new one — so a page of writing lands as prose,
// not as one choppy line per photographed line.
//
// Files → .txt as-is; .md with the markup quietly stripped (headings,
// emphasis, links, bullets become plain writing); .pdf via its text
// layer, falling back to OCR of the rendered pages when the PDF is a
// scan; images through the same OCR path. Legacy Word files can't be
// read on iOS — the error says so in product language.

import UIKit
import Vision
import PDFKit
import UniformTypeIdentifiers

enum ImportCapture {

    enum Failure: LocalizedError {
        case unreadable
        case wordFile
        case noText

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Couldn't read that file."
            case .wordFile:   return "Word files can't be opened here — export as PDF or text first."
            case .noText:     return "No writing found."
            }
        }
    }

    // MARK: - Photos

    /// Recognize the writing in an image and rebuild its paragraphs.
    static func text(from image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw Failure.unreadable }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // Pin the strongest configuration for handwriting: the latest
        // model revision, one explicit language (auto-detect wastes
        // capacity guessing), and no minimum text height so small script
        // still enters the pass. Vision is print-first; this is the
        // ceiling of what it offers on-device.
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLanguages = ["en-US"]
        request.automaticallyDetectsLanguage = false
        request.minimumTextHeight = 0
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation(of: image))
        try await Task.detached(priority: .userInitiated) {
            try handler.perform([request])
        }.value
        let observations = request.results ?? []
        let text = paragraphs(from: observations)
        guard !text.isEmpty else { throw Failure.noText }
        return text
    }

    /// Multi-page capture (the document camera) — pages join as paragraphs.
    static func text(fromPages images: [UIImage]) async throws -> String {
        var pages: [String] = []
        for image in images {
            if let t = try? await text(from: image) { pages.append(t) }
        }
        guard !pages.isEmpty else { throw Failure.noText }
        return pages.joined(separator: "\n")
    }

    /// Vision returns one observation per visual line. Wrapped lines of the
    /// same paragraph join with spaces; a vertical gap larger than the
    /// typical line height starts a new paragraph (a new line on the page).
    private static func paragraphs(from observations: [VNRecognizedTextObservation]) -> String {
        let lines: [(text: String, box: CGRect)] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            return (candidate.string, obs.boundingBox)
        }
        .sorted { $0.box.midY > $1.box.midY }   // Vision's y grows upward
        guard !lines.isEmpty else { return "" }

        let typicalHeight = lines.map(\.box.height).sorted()[lines.count / 2]
        var out = lines[0].text
        for i in 1..<lines.count {
            let gap = lines[i - 1].box.minY - lines[i].box.maxY
            out += gap > typicalHeight * 0.8 ? "\n" : " "
            out += lines[i].text
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: - Files

    /// Extract the writing from a picked file. The URL comes from the file
    /// importer, so it needs security-scoped access.
    static func text(fromFile url: URL) async throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        switch url.pathExtension.lowercased() {
        case "txt":
            return try plainText(at: url)
        case "md", "markdown":
            return stripMarkdown(try plainText(at: url))
        case "pdf":
            return try await pdfText(at: url)
        case "doc", "docx":
            throw Failure.wordFile
        case "png", "jpg", "jpeg", "heic", "heif":
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { throw Failure.unreadable }
            return try await text(from: image)
        default:
            // Trust content over extension for anything else the picker let
            // through: try text, then image.
            if let t = try? plainText(at: url) { return t }
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return try await text(from: image)
            }
            throw Failure.unreadable
        }
    }

    private static func plainText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else { throw Failure.unreadable }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.noText }
        return trimmed
    }

    private static func pdfText(at url: URL) async throws -> String {
        guard let doc = PDFDocument(url: url) else { throw Failure.unreadable }
        let layer = (doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !layer.isEmpty { return normalize(layer) }

        // No text layer — it's a scan. Render the pages and read them.
        var images: [UIImage] = []
        for i in 0..<min(doc.pageCount, 20) {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale = 2.0
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            images.append(renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            })
        }
        return try await text(fromPages: images)
    }

    /// PDF text layers arrive with hard line breaks mid-paragraph; collapse
    /// single breaks to spaces, keep blank lines as paragraph breaks.
    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.replacingOccurrences(of: "\n", with: " ")
                     .replacingOccurrences(of: "  ", with: " ")
                     .trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Markdown lands as plain writing: heading marks, emphasis, links, and
    /// bullet syntax dissolve; the words stay.
    private static func stripMarkdown(_ text: String) -> String {
        var lines: [String] = []
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            while line.hasPrefix("#") { line.removeFirst() }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { line = "– " + line.dropFirst(2) }
            if line.hasPrefix("> ") { line = String(line.dropFirst(2)) }
            line = line.replacingOccurrences(of: "**", with: "")
                       .replacingOccurrences(of: "__", with: "")
                       .replacingOccurrences(of: "`", with: "")
            // [text](url) → text
            while let open = line.range(of: "["),
                  let mid = line.range(of: "](", range: open.upperBound..<line.endIndex),
                  let close = line.range(of: ")", range: mid.upperBound..<line.endIndex) {
                let label = line[open.upperBound..<mid.lowerBound]
                line.replaceSubrange(open.lowerBound..<close.upperBound, with: label)
            }
            lines.append(line.trimmingCharacters(in: .whitespaces))
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// The file picker's accepted types.
    static var fileTypes: [UTType] {
        var types: [UTType] = [.png, .jpeg, .heic, .plainText, .pdf]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let doc = UTType("com.microsoft.word.doc") { types.append(doc) }
        if let docx = UTType("org.openxmlformats.wordprocessingml.document") { types.append(docx) }
        return types
    }
}
