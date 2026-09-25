package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgeRAGOrchestrationTest {
    @Test
    fun runRetrievesContextAndGeneratesAnswer() = runTest {
        val retriever = EdgeRetriever(
            embeddingProvider =
                RAGKeywordEmbeddingProvider(),
            vectorStore =
                EdgeInMemoryVectorStore()
        )

        val collection =
            EdgeKnowledgeCollection(
                id = "travel",
                name = "Travel"
            )

        retriever.index(
            document = EdgeDocument(
                id = "flight",
                text =
                    "The Tokyo flight leaves Newark at 9:30 AM.",
                metadata = mapOf(
                    "source" to "trip.txt"
                )
            ),
            collection = collection
        )

        retriever.index(
            document = EdgeDocument(
                id = "dinner",
                text =
                    "Dinner is reserved at 7 PM.",
                metadata = mapOf(
                    "source" to "food.txt"
                )
            ),
            collection = collection
        )

        val rag = EdgeRAG(
            retriever = retriever,
            agent = EdgeAgent(
                EdgeProviderRouter(
                    listOf(RAGEchoProvider())
                )
            )
        )

        val result = rag.run(
            query =
                "When does my Tokyo flight leave?",
            collection = collection,
            topK = 1
        )

        assertEquals(
            1,
            result.retrievedResults.size
        )
        assertEquals(
            "flight",
            result.retrievedResults
                .first()
                .chunk
                .documentId
        )
        assertTrue(
            result.context.contains(
                "The Tokyo flight leaves Newark at 9:30 AM."
            )
        )
        assertTrue(
            result.answer.contains(
                "When does my Tokyo flight leave?"
            )
        )
        assertTrue(
            result.answer.contains(
                "--- BEGIN LOCAL CONTEXT ---"
            )
        )

        val metrics =
            requireNotNull(result.metrics)

        assertEquals(
            1,
            metrics.requestedTopK
        )
        assertEquals(
            1,
            metrics.retainedResultCount
        )
        assertEquals(
            1,
            metrics.retrieval.resultCount
        )
        assertEquals(
            result.context.length,
            metrics.contextCharacterCount
        )
        assertTrue(
            metrics.retrieval
                .embeddingMilliseconds >= 0
        )
        assertTrue(
            metrics.retrieval
                .searchMilliseconds >= 0
        )
        assertTrue(
            metrics.generationMilliseconds >= 0
        )
        assertTrue(
            metrics.totalMilliseconds >=
                metrics.retrieval
                    .totalMilliseconds
        )
    }

    @Test
    fun minimumScoreFiltersWeakResults() = runTest {
        val retriever = EdgeRetriever(
            embeddingProvider =
                RAGKeywordEmbeddingProvider(),
            vectorStore =
                EdgeInMemoryVectorStore()
        )

        retriever.index(
            listOf(
                EdgeChunk(
                    id = "flight",
                    documentId = "flight",
                    text =
                        "Tokyo flight from Newark."
                ),
                EdgeChunk(
                    id = "dinner",
                    documentId = "dinner",
                    text =
                        "Italian dinner reservation."
                )
            )
        )

        val rag = EdgeRAG(
            retriever = retriever,
            agent = EdgeAgent(
                EdgeProviderRouter(
                    listOf(RAGEchoProvider())
                )
            )
        )

        val result = rag.run(
            EdgeRAGRequest(
                query = "Tokyo flight",
                topK = 2,
                minimumScore = 0.9f
            )
        )

        assertEquals(
            1,
            result.retrievedResults.size
        )
        assertEquals(
            "flight",
            result.retrievedResults
                .first()
                .chunk
                .id
        )
        assertEquals(
            1,
            result.metrics
                ?.retainedResultCount
        )
        assertEquals(
            2,
            result.metrics
                ?.retrieval
                ?.resultCount
        )
    }
}

private class RAGEchoProvider :
    EdgeModelProvider {
    override val id = "rag-echo"

    override suspend fun capabilities():
        Set<EdgeCapability> {
        return setOf(
            EdgeCapability.TEXT_GENERATION
        )
    }

    override suspend fun generate(
        request: EdgeGenerationRequest
    ): EdgeGenerationResponse {
        return EdgeGenerationResponse(
            request.prompt
        )
    }

    override fun stream(
        request: EdgeGenerationRequest
    ) = emptyFlow<EdgeGenerationEvent>()
}

private class RAGKeywordEmbeddingProvider :
    EdgeEmbeddingProvider {
    override suspend fun embed(
        text: String
    ): EdgeEmbedding {
        val normalized =
            text.lowercase()

        val travel = if (
            "tokyo" in normalized ||
            "flight" in normalized ||
            "newark" in normalized
        ) 1f else 0f

        val food = if (
            "dinner" in normalized ||
            "italian" in normalized
        ) 1f else 0f

        return EdgeEmbedding(
            values = listOf(
                travel,
                food
            )
        )
    }
}
