import Foundation
import XCTest
@testable import EdgeFrameworks

final class ApplePDFDocumentImporterTests: XCTestCase {
    func testImportsTextAndPageMetadata() throws {
        let data = makeMinimalPDF(
            text: "Tokyo flight leaves Newark at 9:30 AM."
        )

        let documents = try ApplePDFDocumentImporter().importDocument(
            data: data,
            sourceName: "travel.pdf",
            documentID: "travel"
        )

        XCTAssertEqual(documents.count, 1)
        XCTAssertTrue(
            documents[0].text.contains(
                "Tokyo flight leaves Newark at 9:30 AM."
            )
        )
        XCTAssertEqual(
            documents[0].metadata["source"],
            "travel.pdf"
        )
        XCTAssertEqual(
            documents[0].metadata["mediaType"],
            "application/pdf"
        )
        XCTAssertEqual(
            documents[0].metadata["pageNumber"],
            "1"
        )
        XCTAssertEqual(
            documents[0].metadata["pageCount"],
            "1"
        )
        XCTAssertEqual(
            documents[0].metadata["parentDocumentID"],
            "travel"
        )
    }

    private func makeMinimalPDF(text: String) -> Data {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")

        let stream = """
        BT
        /F1 12 Tf
        72 720 Td
        (\(escaped)) Tj
        ET
        """

        let objects = [
            """
            1 0 obj
            << /Type /Catalog /Pages 2 0 R >>
            endobj
            """,
            """
            2 0 obj
            << /Type /Pages /Kids [3 0 R] /Count 1 >>
            endobj
            """,
            """
            3 0 obj
            << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
            endobj
            """,
            """
            4 0 obj
            << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
            endobj
            """,
            """
            5 0 obj
            << /Length \(stream.utf8.count) >>
            stream
            \(stream)
            endstream
            endobj
            """
        ]

        var output = "%PDF-1.4\n"
        var offsets: [Int] = [0]

        for object in objects {
            offsets.append(output.utf8.count)
            output += object + "\n"
        }

        let xrefOffset = output.utf8.count

        output += "xref\n"
        output += "0 \(objects.count + 1)\n"
        output += "0000000000 65535 f \n"

        for offset in offsets.dropFirst() {
            output += String(
                format: "%010d 00000 n \n",
                offset
            )
        }

        output += """
        trailer
        << /Size \(objects.count + 1) /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """

        return Data(output.utf8)
    }
}
