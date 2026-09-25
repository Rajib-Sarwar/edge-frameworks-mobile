package io.github.rajibsarwar.edgeframeworks.documents

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidRichDocumentImporterTest {
    private val importer = AndroidRichDocumentImporter()

    @Test
    fun htmlImportExtractsReadableTextAndMetadata() {
        val document = importer.importHtml(
            html = """
                <html>
                  <head>
                    <style>.hidden { color: red; }</style>
                    <script>ignoreMe()</script>
                  </head>
                  <body>
                    <h1>Tokyo Trip</h1>
                    <p>Flight leaves Newark at 9:30 AM.</p>
                  </body>
                </html>
            """.trimIndent(),
            sourceName = "trip.html",
            documentId = "trip"
        )

        assertTrue(
            document.text.contains("Tokyo Trip")
        )
        assertTrue(
            document.text.contains(
                "Flight leaves Newark at 9:30 AM."
            )
        )
        assertFalse(
            document.text.contains("ignoreMe")
        )
        assertEquals(
            "html",
            document.metadata["documentFormat"]
        )
    }

    @Test
    fun docxXmlPreservesParagraphsTabsAndBreaks() {
        val xml = """
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
        """.trimIndent()

        val text = importer.plainTextFromDocxXml(
            xml.toByteArray()
        )

        assertTrue(
            text.contains("Tokyo flight\t9:30 AM")
        )
        assertTrue(
            text.contains("Hotel: Shinagawa")
        )
        assertTrue(
            text.contains("Four nights")
        )
    }
}
