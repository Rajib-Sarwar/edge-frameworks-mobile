package io.github.rajibsarwar.edgeframeworks

import java.io.File
import kotlin.io.path.createTempDirectory
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgePersistentRagTest {
    @Test
    fun chunkerSplitsDocumentAndPreservesMetadata() {
        val document = EdgeDocument(
            id = "guide",
            text = """
                First paragraph explains the flight details.

                Second paragraph explains the hotel details.

                Third paragraph explains the train details.
            """.trimIndent(),
            metadata = mapOf("source" to "guide.txt")
        )

        val chunks = EdgeTextChunker(
            maxCharacters = 60,
            overlapCharacters = 10
        ).chunk(document)

        assertTrue(chunks.size > 1)
        assertEquals("guide", chunks.first().documentId)
        assertEquals("guide.txt", chunks.first().metadata["source"])
        assertEquals("0", chunks.first().metadata["chunkIndex"])
    }

    @Test
    fun fileVectorStoreSurvivesReopen() = runTest {
        val directory = createTempDirectory(
            prefix = "edge-rag-"
        ).toFile()
        val file = File(directory, "vectors.bin")

        val firstStore = EdgeFileVectorStore(file)

        val chunk = EdgeChunk(
            id = "flight",
            documentId = "travel",
            text = "Tokyo flight leaves Newark at 9:30 AM."
        )

        firstStore.upsert(
            chunks = listOf(chunk),
            embeddings = listOf(
                EdgeEmbedding(listOf(1f, 0f))
            )
        )

        val reopenedStore = EdgeFileVectorStore(file)

        val results = reopenedStore.search(
            query = EdgeEmbedding(listOf(1f, 0f)),
            topK = 1
        )

        assertEquals(chunk, results.first().chunk)
        assertEquals(1f, results.first().score, 0.0001f)

        directory.deleteRecursively()
    }
}
