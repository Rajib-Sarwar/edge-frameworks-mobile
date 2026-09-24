package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgeRagTest {
    @Test
    fun cosineSimilarityRanksAlignedVectorsHigher() {
        val aligned = EdgeVectorMath.cosineSimilarity(
            EdgeEmbedding(listOf(1f, 0f)),
            EdgeEmbedding(listOf(1f, 0f))
        )

        val orthogonal = EdgeVectorMath.cosineSimilarity(
            EdgeEmbedding(listOf(1f, 0f)),
            EdgeEmbedding(listOf(0f, 1f))
        )

        assertEquals(1f, aligned, 0.0001f)
        assertEquals(0f, orthogonal, 0.0001f)
        assertTrue(aligned > orthogonal)
    }

    @Test
    fun retrieverIndexesAndReturnsMostRelevantChunk() = runTest {
        val retriever = EdgeRetriever(
            embeddingProvider = KeywordEmbeddingProvider(),
            vectorStore = EdgeInMemoryVectorStore()
        )

        val chunks = listOf(
            EdgeChunk(
                id = "travel",
                documentId = "notes",
                text = "Flight leaves Newark for Tokyo on October 12."
            ),
            EdgeChunk(
                id = "food",
                documentId = "notes",
                text = "Dinner reservation is at the Italian restaurant."
            )
        )

        retriever.index(chunks)

        val results = retriever.retrieve(
            query = "When is my Japan flight?",
            topK = 1
        )

        assertEquals(1, results.size)
        assertEquals("travel", results.first().chunk.id)
        assertTrue(results.first().score > 0.9f)
    }

    @Test
    fun vectorStoreUpsertReplacesChunkByIdentifier() = runTest {
        val store = EdgeInMemoryVectorStore()

        store.upsert(
            chunks = listOf(
                EdgeChunk(
                    id = "same",
                    documentId = "doc",
                    text = "old"
                )
            ),
            embeddings = listOf(
                EdgeEmbedding(listOf(1f, 0f))
            )
        )

        store.upsert(
            chunks = listOf(
                EdgeChunk(
                    id = "same",
                    documentId = "doc",
                    text = "new"
                )
            ),
            embeddings = listOf(
                EdgeEmbedding(listOf(0f, 1f))
            )
        )

        val results = store.search(
            query = EdgeEmbedding(listOf(0f, 1f)),
            topK = 3
        )

        assertEquals(1, results.size)
        assertEquals("new", results.first().chunk.text)
    }

    @Test
    fun vectorStoreRejectsMismatchedItemCounts() = runTest {
        val store = EdgeInMemoryVectorStore()

        try {
            store.upsert(
                chunks = listOf(
                    EdgeChunk(
                        id = "one",
                        documentId = "doc",
                        text = "one"
                    )
                ),
                embeddings = emptyList()
            )
            throw AssertionError("Expected count mismatch")
        } catch (error: EdgeVectorException.CountMismatch) {
            assertEquals(1, error.expected)
            assertEquals(0, error.actual)
        }
    }
}

private class KeywordEmbeddingProvider : EdgeEmbeddingProvider {
    override suspend fun embed(text: String): EdgeEmbedding {
        val normalized = text.lowercase()

        val travel = if (
            "tokyo" in normalized ||
            "japan" in normalized ||
            "flight" in normalized ||
            "newark" in normalized
        ) 1f else 0f

        val food = if (
            "dinner" in normalized ||
            "restaurant" in normalized ||
            "italian" in normalized
        ) 1f else 0f

        return EdgeEmbedding(
            values = listOf(travel, food)
        )
    }
}
