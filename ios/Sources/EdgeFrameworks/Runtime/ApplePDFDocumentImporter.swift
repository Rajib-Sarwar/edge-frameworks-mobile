import CoreGraphics
import Foundation
import PDFKit
import Vision

public enum ApplePDFDocumentImportError: Error, Equatable, Sendable {
    case invalidPDF
    case noExtractableText
    case pageRenderFailed(pageNumber: Int)
}

public struct ApplePDFDocumentImporter: Sendable {
    public init() {}

    public func importDocument(
        data: Data,
        sourceName: String,
        documentID: String = UUID().uuidString
    ) throws -> [EdgeDocument] {
        guard let pdf = PDFDocument(data: data) else {
            throw ApplePDFDocumentImportError.invalidPDF
        }

        let pageCount = pdf.pageCount
        var documents: [EdgeDocument] = []
        documents.reserveCapacity(pageCount)

        for index in 0..<pageCount {
            guard
                let page = pdf.page(at: index),
                let text = page.string?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            else {
                continue
            }

            documents.append(
                pageDocument(
                    documentID: documentID,
                    sourceName: sourceName,
                    pageNumber: index + 1,
                    pageCount: pageCount,
                    text: text,
                    extractionMethod: "embeddedText"
                )
            )
        }

        guard !documents.isEmpty else {
            throw ApplePDFDocumentImportError.noExtractableText
        }

        return documents
    }

    public func importDocumentWithOCR(
        data: Data,
        sourceName: String,
        documentID: String = UUID().uuidString
    ) async throws -> [EdgeDocument] {
        guard let pdf = PDFDocument(data: data) else {
            throw ApplePDFDocumentImportError.invalidPDF
        }

        let pageCount = pdf.pageCount
        var documents: [EdgeDocument] = []
        documents.reserveCapacity(pageCount)

        for index in 0..<pageCount {
            try Task.checkCancellation()

            guard let page = pdf.page(at: index) else {
                continue
            }

            let embeddedText = page.string?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let embeddedText, !embeddedText.isEmpty {
                documents.append(
                    pageDocument(
                        documentID: documentID,
                        sourceName: sourceName,
                        pageNumber: index + 1,
                        pageCount: pageCount,
                        text: embeddedText,
                        extractionMethod: "embeddedText"
                    )
                )
                continue
            }

            guard let image = render(page: page) else {
                throw ApplePDFDocumentImportError.pageRenderFailed(
                    pageNumber: index + 1
                )
            }

            let recognizedText = try recognizeText(
                in: image
            )

            guard !recognizedText.isEmpty else {
                continue
            }

            documents.append(
                pageDocument(
                    documentID: documentID,
                    sourceName: sourceName,
                    pageNumber: index + 1,
                    pageCount: pageCount,
                    text: recognizedText,
                    extractionMethod: "ocr"
                )
            )
        }

        guard !documents.isEmpty else {
            throw ApplePDFDocumentImportError.noExtractableText
        }

        return documents
    }

    private func pageDocument(
        documentID: String,
        sourceName: String,
        pageNumber: Int,
        pageCount: Int,
        text: String,
        extractionMethod: String
    ) -> EdgeDocument {
        EdgeDocument(
            id: "\(documentID)-page-\(pageNumber)",
            text: text,
            metadata: [
                "source": sourceName,
                "mediaType": "application/pdf",
                "pageNumber": String(pageNumber),
                "pageCount": String(pageCount),
                "parentDocumentID": documentID,
                "extractionMethod": extractionMethod,
                "ocrEngine": extractionMethod == "ocr"
                    ? "Apple Vision"
                    : "none"
            ]
        )
    }

    private func render(
        page: PDFPage,
        scale: CGFloat = 2
    ) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width = max(
            Int(bounds.width * scale),
            1
        )
        let height = max(
            Int(bounds.height * scale),
            1
        )

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.setFillColor(
            CGColor(
                red: 1,
                green: 1,
                blue: 1,
                alpha: 1
            )
        )
        context.fill(
            CGRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
        )

        context.saveGState()
        context.scaleBy(
            x: scale,
            y: scale
        )
        page.draw(
            with: .mediaBox,
            to: context
        )
        context.restoreGState()

        return context.makeImage()
    }

    private func recognizeText(
        in image: CGImage
    ) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(
            cgImage: image,
            options: [:]
        )

        try handler.perform([request])

        return (request.results ?? [])
            .compactMap {
                $0.topCandidates(1).first?.string
            }
            .joined(separator: "\n")
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }
}
