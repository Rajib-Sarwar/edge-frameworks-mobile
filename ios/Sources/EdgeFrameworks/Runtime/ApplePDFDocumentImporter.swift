import Foundation
import PDFKit

public enum ApplePDFDocumentImportError: Error, Equatable, Sendable {
    case invalidPDF
    case noExtractableText
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
                EdgeDocument(
                    id: "\(documentID)-page-\(index + 1)",
                    text: text,
                    metadata: [
                        "source": sourceName,
                        "mediaType": "application/pdf",
                        "pageNumber": String(index + 1),
                        "pageCount": String(pageCount),
                        "parentDocumentID": documentID
                    ]
                )
            )
        }

        guard !documents.isEmpty else {
            throw ApplePDFDocumentImportError.noExtractableText
        }

        return documents
    }
}
