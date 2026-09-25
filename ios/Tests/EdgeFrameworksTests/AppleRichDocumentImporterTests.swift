import Foundation
import XCTest
@testable import EdgeFrameworks

final class AppleRichDocumentImporterTests: XCTestCase {
    func testHTMLImportExtractsReadableTextAndMetadata() throws {
        let html = """
        <html>
          <head><title>Trip</title></head>
          <body>
            <h1>Tokyo Trip</h1>
            <p>Flight leaves Newark at 9:30 AM.</p>
          </body>
        </html>
        """

        let document = try AppleRichDocumentImporter()
            .importHTML(
                data: Data(html.utf8),
                sourceName: "trip.html",
                documentID: "trip"
            )

        XCTAssertEqual(document.id, "trip")
        XCTAssertTrue(
            document.text.contains("Tokyo Trip")
        )
        XCTAssertTrue(
            document.text.contains(
                "Flight leaves Newark at 9:30 AM."
            )
        )
        XCTAssertEqual(
            document.metadata["documentFormat"],
            "html"
        )
    }

    func testDOCXXMLPreservesParagraphsTabsAndBreaks() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document
          xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p>
              <w:r><w:t>Tokyo flight</w:t></w:r>
              <w:r><w:tab/></w:r>
              <w:r><w:t>9:30 AM</w:t></w:r>
            </w:p>
            <w:p>
              <w:r><w:t>Hotel: Shinagawa</w:t></w:r>
              <w:r><w:br/></w:r>
              <w:r><w:t>Four nights</w:t></w:r>
            </w:p>
          </w:body>
        </w:document>
        """

        let text = try AppleRichDocumentImporter
            .plainTextFromDOCXXML(
                Data(xml.utf8)
            )

        XCTAssertTrue(
            text.contains("Tokyo flight\t9:30 AM")
        )
        XCTAssertTrue(
            text.contains("Hotel: Shinagawa")
        )
        XCTAssertTrue(
            text.contains("Four nights")
        )
    }
}
