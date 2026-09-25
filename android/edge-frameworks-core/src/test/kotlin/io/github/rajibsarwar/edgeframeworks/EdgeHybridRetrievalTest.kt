package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class EdgeHybridRetrievalTest {
    @Test
    fun hybridRetrievalRescuesExactIdentifier() = runTest {
        val retriever = EdgeRetriever(
            embeddingProvider =
                HybridTestEmbeddingProvider(),
            vectorStore =
                EdgeInMemoryVectorStore()
        )

        retriever.index(
            listOf(
                EdgeChunk(
                    id = "semantic",
                    documentId = "semantic",
                    text =
                        "General compressor troubleshooting guidance."
                ),
                EdgeChunk(
                    id = "exact",
                    documentId = "manual",
                    text =
                        "Fault code E31 means condenser airflow is restricted."
                )
            )
        )

        val vectorOnly = retriever.retrieve(
            query = "E31",
            topK = 1
        )

        val hybrid = retriever.retrieveHybrid(
            query = "E31",
            topK = 1
        )

        assertEquals(
            "semantic",
            vectorOnly.first().chunk.id
        )
        assertEquals(
            "exact",
            hybrid.first().chunk.id
        )
    }

    @Test
    fun lexicalSearchHonorsCollectionFilter() = runTest {
        val store = EdgeInMemoryVectorStore()

        store.upsert(
            chunks = listOf(
                EdgeChunk(
                    id = "a",
                    documentId = "a",
                    text = "Fault E31",
                    metadata = mapOf(
                        "collectionID" to "one"
                    )
                ),
                EdgeChunk(
                    id = "b",
                    documentId = "b",
                    text = "Fault E31",
                    metadata = mapOf(
                        "collectionID" to "two"
                    )
                )
            ),
            embeddings = listOf(
                EdgeEmbedding(
                    values = listOf(1f, 0f)
                ),
                EdgeEmbedding(
                    values = listOf(1f, 0f)
                )
            )
        )

        val results = store.lexicalSearch(
            query = "E31",
            topK = 10,
            filter = EdgeVectorFilter(
                collectionId = "two"
            )
        )

        assertEquals(
            listOf("b"),
            results.map { it.chunk.id }
        )
    }
}

private class HybridTestEmbeddingProvider :
    EdgeEmbeddingProvider {
    override suspend fun embed(
        text: String
    ): EdgeEmbedding {
        if (
            text.lowercase()
                .contains("fault code e31")
        ) {
            return EdgeEmbedding(
                values = listOf(0f, 1f)
            )
        }

        return EdgeEmbedding(
            values = listOf(1f, 0f)
        )
    }
}
