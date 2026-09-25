import Foundation
import ImageIO
import Vision

public enum AppleImageDocumentImportError:
    Error,
    Equatable,
    Sendable
{
    case invalidImage
    case noRecognizedText
}

public struct AppleImageDocumentImporter: Sendable {
    public init() {}

    public func importDocument(
        data: Data,
        sourceName: String,
        mediaType: String = "image/*",
        documentID: String = UUID().uuidString
    ) throws -> EdgeDocument {
        guard
            let source = CGImageSourceCreateWithData(
                data as CFData,
                nil
            ),
            let image = CGImageSourceCreateImageAtIndex(
                source,
                0,
                nil
            )
        else {
            throw AppleImageDocumentImportError.invalidImage
        }

        let orientation = imageOrientation(
            source: source
        )

        let text = try recognizeText(
            in: image,
            orientation: orientation
        )

        guard !text.isEmpty else {
            throw AppleImageDocumentImportError.noRecognizedText
        }

        return Self.imageDocument(
            documentID: documentID,
            sourceName: sourceName,
            mediaType: mediaType,
            text: text
        )
    }

    static func imageDocument(
        documentID: String,
        sourceName: String,
        mediaType: String,
        text: String
    ) -> EdgeDocument {
        EdgeDocument(
            id: documentID,
            text: text,
            metadata: [
                "source": sourceName,
                "mediaType": mediaType,
                "documentFormat": "image",
                "extractionMethod": "ocr",
                "ocrEngine": "Apple Vision"
            ]
        )
    }

    private func recognizeText(
        in image: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: orientation,
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

    private func imageOrientation(
        source: CGImageSource
    ) -> CGImagePropertyOrientation {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                nil
            ) as? [CFString: Any],
            let rawValue =
                properties[kCGImagePropertyOrientation]
                as? UInt32,
            let orientation =
                CGImagePropertyOrientation(
                    rawValue: rawValue
                )
        else {
            return .up
        }

        return orientation
    }
}
