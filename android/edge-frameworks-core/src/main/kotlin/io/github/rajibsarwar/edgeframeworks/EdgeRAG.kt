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
        systemPrompt: String? = null
    ): EdgeRAGResult {
        return run(
            EdgeRAGRequest(
                query = query,
                collection = collection,
                topK = topK,
                minimumScore = minimumScore,
                systemPrompt = systemPrompt
            )
        )
    }

    suspend fun run(
        request: EdgeRAGRequest
    ): EdgeRAGResult {
        coroutineContext.ensureActive()

        val filter = combinedFilter(
            collection = request.collection,
            filter = request.filter
        )

        val retrieved = retriever.retrieve(
            query = request.query,
            filter = filter,
            topK = request.topK
        )

        val filtered =
            request.minimumScore?.let { minimum ->
                retrieved.filter {
                    it.score >= minimum
                }
            } ?: retrieved

        val context = buildContext(
            filtered
        )

        coroutineContext.ensureActive()

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

        return EdgeRAGResult(
            answer = response.text,
            retrievedResults = filtered,
            context = context
        )
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
