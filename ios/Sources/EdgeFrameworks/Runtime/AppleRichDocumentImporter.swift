import Foundation
import ZIPFoundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum AppleRichDocumentImportError: Error, Equatable, Sendable {
    case invalidHTML
    case invalidDOCX
    case missingDOCXDocumentXML
    case noExtractableText
}

public struct AppleRichDocumentImporter: Sendable {
    public init() {}

    public func importHTML(
        data: Data,
        sourceName: String,
        documentID: String = UUID().uuidString
    ) throws -> EdgeDocument {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard
            let attributed = try? NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )
        else {
            throw AppleRichDocumentImportError.invalidHTML
        }

        let text = Self.normalizedText(attributed.string)

        guard !text.isEmpty else {
            throw AppleRichDocumentImportError.noExtractableText
        }

        return EdgeDocument(
            id: documentID,
            text: text,
            metadata: [
                "source": sourceName,
                "mediaType": "text/html",
                "documentFormat": "html",
                "extractionMethod": "htmlParser"
            ]
        )
    }

    public func importDOCX(
        data: Data,
        sourceName: String,
        documentID: String = UUID().uuidString
    ) throws -> EdgeDocument {
        let archive: Archive

        do {
            archive = try Archive(
                data: data,
                accessMode: .read
            )
        } catch {
            throw AppleRichDocumentImportError.invalidDOCX
        }

        guard let entry = archive["word/document.xml"] else {
            throw AppleRichDocumentImportError.missingDOCXDocumentXML
        }

        var xml = Data()

        do {
            _ = try archive.extract(entry) { chunk in
                xml.append(chunk)
            }
        } catch {
            throw AppleRichDocumentImportError.invalidDOCX
        }

        let text = try Self.plainTextFromDOCXXML(xml)

        guard !text.isEmpty else {
            throw AppleRichDocumentImportError.noExtractableText
        }

        return EdgeDocument(
            id: documentID,
            text: text,
            metadata: [
                "source": sourceName,
                "mediaType": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                "documentFormat": "docx",
                "extractionMethod": "wordprocessingML"
            ]
        )
    }

    static func plainTextFromDOCXXML(
        _ data: Data
    ) throws -> String {
        let delegate = DOCXTextParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw AppleRichDocumentImportError.invalidDOCX
        }

        return normalizedText(delegate.text)
    }

    private static func normalizedText(
        _ text: String
    ) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }
}

private final class DOCXTextParserDelegate:
    NSObject,
    XMLParserDelegate
{
    var text = ""

    private var isTextElement = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = qName ?? elementName

        if name.hasSuffix(":t") || name == "t" {
            isTextElement = true
        } else if name.hasSuffix(":tab") || name == "tab" {
            text.append("\t")
        } else if name.hasSuffix(":br") || name == "br" {
            text.append("\n")
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        if isTextElement {
            text.append(string)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = qName ?? elementName

        if name.hasSuffix(":t") || name == "t" {
            isTextElement = false
        } else if name.hasSuffix(":p") || name == "p" {
            text.append("\n")
        }
    }
}
