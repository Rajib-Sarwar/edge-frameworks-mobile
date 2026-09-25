package io.github.rajibsarwar.edgeframeworks.pdf

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidPDFDocumentImporterTest {
    @Test
    fun pageDocumentPreservesSourceAndPageMetadata() {
        val document = AndroidPDFDocumentImporter.pageDocument(
            documentId = "travel",
            sourceName = "travel.pdf",
            pageNumber = 2,
            pageCount = 5,
            text = "Hotel check-in is October 13.",
            extractionMethod = "ocr"
        )

        assertEquals(
            "travel-page-2",
            document.id
        )
        assertEquals(
            "travel.pdf",
            document.metadata["source"]
        )
        assertEquals(
            "application/pdf",
            document.metadata["mediaType"]
        )
        assertEquals(
            "2",
            document.metadata["pageNumber"]
        )
        assertEquals(
            "5",
            document.metadata["pageCount"]
        )
        assertEquals(
            "travel",
            document.metadata["parentDocumentID"]
        )
        assertEquals(
            "ocr",
            document.metadata["extractionMethod"]
        )
        assertEquals(
            "ML Kit Text Recognition",
            document.metadata["ocrEngine"]
        )
    }
}
