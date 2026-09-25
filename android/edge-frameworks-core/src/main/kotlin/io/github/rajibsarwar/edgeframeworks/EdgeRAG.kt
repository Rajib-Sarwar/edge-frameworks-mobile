package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.ensureActive
import kotlin.coroutines.coroutineContext

class EdgeRAG(
    private val retriever: EdgeRetriever,
    private val agent: EdgeAgent
) {
    suspend fun run(
        query: String,
        collection: EdgeKnowledgeCollection? = null,
        topK: Int = 3,
        minimumScore: Float? = null,
        retrievalMode: EdgeRetrievalMode =
            EdgeRetrievalMode.VECTOR,
        systemPrompt: String? = null
    ): EdgeRAGResult {
        return run(
            EdgeRAGRequest(
                query = query,
                collection = collection,
                topK = topK,
                minimumScore = minimumScore,
                retrievalMode = retrievalMode,
                systemPrompt = systemPrompt
            )
        )
    }

    suspend fun run(
        request: EdgeRAGRequest
    ): EdgeRAGResult {
        coroutineContext.ensureActive()

        val totalStart = System.nanoTime()

        val filter = combinedFilter(
            collection = request.collection,
            filter = request.filter
        )

        val measuredRetrieval =
            when (request.retrievalMode) {
                EdgeRetrievalMode.VECTOR ->
                    retriever.retrieveMeasured(
                        query = request.query,
                        filter = filter,
                        topK = request.topK
                    )

                EdgeRetrievalMode.HYBRID ->
                    retriever.retrieveHybridMeasured(
                        query = request.query,
                        filter = filter,
                        topK = request.topK
                    )
            }

        val filtered =
            request.minimumScore?.let { minimum ->
                measuredRetrieval.results.filter {
                    it.score >= minimum
                }
            } ?: measuredRetrieval.results

        val context = buildContext(
            filtered
        )

        coroutineContext.ensureActive()

        val generationStart = System.nanoTime()

        val response = agent.run(
            EdgeGenerationRequest(
                prompt = buildPrompt(
                    query = request.query,
                    context = context
                ),
                systemPrompt =
                    request.systemPrompt
                        ?: DEFAULT_SYSTEM_PROMPT
            )
        )

        val generationEnd = System.nanoTime()

        return EdgeRAGResult(
            answer = response.text,
            retrievedResults = filtered,
            context = context,
            metrics = EdgeRAGMetrics(
                retrieval =
                    measuredRetrieval.metrics,
                generationMilliseconds =
                    milliseconds(
                        generationStart,
                        generationEnd
                    ),
                totalMilliseconds =
                    milliseconds(
                        totalStart,
                        generationEnd
                    ),
                requestedTopK =
                    request.topK,
                retainedResultCount =
                    filtered.size,
                contextCharacterCount =
                    context.length
            )
        )
    }

    private fun milliseconds(
        start: Long,
        end: Long
    ): Double {
        return (end - start) / 1_000_000.0
    }

    private fun combinedFilter(
        collection: EdgeKnowledgeCollection?,
        filter: EdgeVectorFilter?
    ): EdgeVectorFilter? {
        if (collection == null && filter == null) {
            return null
        }

        return EdgeVectorFilter(
            documentId = filter?.documentId,
            collectionId =
                collection?.id
                    ?: filter?.collectionId,
            metadata =
                filter?.metadata
                    ?: emptyMap()
        )
    }

    companion object {
        val DEFAULT_SYSTEM_PROMPT =
            """
            Answer using only the supplied local context.
            If the context does not contain enough information, say that the local knowledge does not contain enough information.
            Do not invent facts that are not present in the context.
            """.trimIndent()

        fun buildContext(
            results: List<EdgeSearchResult>
        ): String {
            return results
                .mapIndexed { index, result ->
                    val source =
                        result.chunk.metadata["source"]
                            ?: result.chunk.documentId

                    val page =
                        result.chunk.metadata["pageNumber"]
                            ?.let { " · page $it" }
                            ?: ""

                    """
                    [${index + 1}] $source$page
                    ${result.chunk.text}
                    """.trimIndent()
                }
                .joinToString("\n\n")
        }

        fun buildPrompt(
            query: String,
            context: String
        ): String {
            return """
                Local context:
                --- BEGIN LOCAL CONTEXT ---
                $context
                --- END LOCAL CONTEXT ---

                Question:
                $query
            """.trimIndent()
        }
    }
}
