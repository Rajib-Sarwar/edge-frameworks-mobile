package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
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
    fun hybridRetrievalPrioritizesIdentifierInsideNaturalLanguageQuery() = runTest {
        val retriever = EdgeRetriever(
            embeddingProvider =
                NaturalLanguageIdentifierEmbeddingProvider(),
            vectorStore =
                EdgeInMemoryVectorStore()
        )

        retriever.index(
            listOf(
                EdgeChunk(
                    id = "generic-indoor-outdoor",
                    documentId = "manual-page-9",
                    text =
                        "Indoor and outdoor unit installation model selection guidance."
                ),
                EdgeChunk(
                    id = "generic-outdoor",
                    documentId = "manual-page-19",
                    text =
                        "Outdoor unit model wiring installation."
                ),
                EdgeChunk(
                    id = "generic-indoor",
                    documentId = "manual-page-12",
                    text =
                        "Indoor unit installation safety."
                ),
                EdgeChunk(
                    id = "exact-model",
                    documentId = "manual-page-1",
                    text =
                        "INDOOR UNITS Type Model DCP09NWB11S DHP09NWB11S DCP12NWB11S."
                )
            )
        )

        val query =
            "Is model DCP09NWB11S an indoor or outdoor unit?"

        val vectorOnly = retriever.retrieve(
            query = query,
            topK = 1
        )

        val hybrid = retriever.retrieveHybrid(
            query = query,
            topK = 1
        )

        assertNotEquals(
            "exact-model",
            vectorOnly.first().chunk.id
        )
        assertEquals(
            "exact-model",
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


private class NaturalLanguageIdentifierEmbeddingProvider :
    EdgeEmbeddingProvider {
    override suspend fun embed(
        text: String
    ): EdgeEmbedding {
        val normalized = text.lowercase()

        if (
            normalized.startsWith(
                "is model dcp09nwb11s"
            )
        ) {
            return EdgeEmbedding(
                values = listOf(1f, 0f)
            )
        }

        if (
            normalized.contains(
                "dcp09nwb11s"
            )
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
