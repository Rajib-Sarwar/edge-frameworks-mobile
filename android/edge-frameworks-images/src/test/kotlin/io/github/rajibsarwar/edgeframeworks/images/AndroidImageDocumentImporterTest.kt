package io.github.rajibsarwar.edgeframeworks.images

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidImageDocumentImporterTest {
    @Test
    fun imageDocumentPreservesOcrMetadata() {
        val document =
            AndroidImageDocumentImporter.imageDocument(
                documentId = "receipt",
                sourceName = "receipt.jpg",
                mediaType = "image/jpeg",
                text = "Total 42.50"
            )

        assertEquals(
            "receipt",
            document.id
        )
        assertEquals(
            "Total 42.50",
            document.text
        )
        assertEquals(
            "receipt.jpg",
            document.metadata["source"]
        )
        assertEquals(
            "image/jpeg",
            document.metadata["mediaType"]
        )
        assertEquals(
            "image",
            document.metadata["documentFormat"]
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
