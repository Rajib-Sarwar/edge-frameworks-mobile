import Foundation
import XCTest
@testable import EdgeFrameworks

final class AppleImageDocumentImporterTests: XCTestCase {
    func testImageDocumentPreservesOCRMetadata() {
        let document =
            AppleImageDocumentImporter.imageDocument(
                documentID: "receipt",
                sourceName: "receipt.jpg",
                mediaType: "image/jpeg",
                text: "Total 42.50"
            )

        XCTAssertEqual(document.id, "receipt")
        XCTAssertEqual(document.text, "Total 42.50")
        XCTAssertEqual(
            document.metadata["source"],
            "receipt.jpg"
        )
        XCTAssertEqual(
            document.metadata["mediaType"],
            "image/jpeg"
        )
        XCTAssertEqual(
            document.metadata["documentFormat"],
            "image"
        )
        XCTAssertEqual(
            document.metadata["extractionMethod"],
            "ocr"
        )
        XCTAssertEqual(
            document.metadata["ocrEngine"],
            "Apple Vision"
        )
    }

    func testInvalidImageThrows() {
        XCTAssertThrowsError(
            try AppleImageDocumentImporter()
                .importDocument(
                    data: Data("not-an-image".utf8),
                    sourceName: "bad.png"
                )
        ) { error in
            XCTAssertEqual(
                error as? AppleImageDocumentImportError,
                .invalidImage
            )
        }
    }
}
