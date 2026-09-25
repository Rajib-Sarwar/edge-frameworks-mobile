import Foundation
import XCTest
@testable import EdgeFrameworks

final class AppleImageDocumentImporterTests: XCTestCase {
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
