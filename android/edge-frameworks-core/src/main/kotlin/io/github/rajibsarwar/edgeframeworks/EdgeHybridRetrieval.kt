package io.github.rajibsarwar.edgeframeworks

interface EdgeLexicalSearchStore {
    suspend fun lexicalSearch(
        query: String,
        topK: Int,
        filter: EdgeVectorFilter? = null
    ): List<EdgeSearchResult>
}

enum class EdgeRetrievalMode {
    VECTOR,
    HYBRID
}

sealed class EdgeRetrievalException(
    message: String
) : Exception(message) {
    data object HybridSearchUnsupported :
        EdgeRetrievalException(
            "The configured vector store does not support lexical search"
        )
}

internal object EdgeLexicalSearch {
    fun search(
        query: String,
        chunks: List<EdgeChunk>,
        topK: Int,
        filter: EdgeVectorFilter?
    ): List<EdgeSearchResult> {
        if (topK <= 0) return emptyList()

        val queryTokens = tokens(query)
        if (queryTokens.isEmpty()) {
            return emptyList()
        }

        val normalizedQuery =
            query.trim().lowercase()

        return chunks.mapNotNull { chunk ->
            if (
                filter != null &&
                !filter.matches(chunk)
            ) {
                return@mapNotNull null
            }

            val chunkTokens =
                tokens(chunk.text).toSet()
            val matched =
                queryTokens.count {
                    it in chunkTokens
                }

            val tokenScore =
                matched.toFloat() /
                    queryTokens.size.toFloat()

            val phraseBonus =
                if (
                    normalizedQuery.isNotEmpty() &&
                    chunk.text.lowercase()
                        .contains(normalizedQuery)
                ) {
                    1f
                } else {
                    0f
                }

            val score =
                tokenScore + phraseBonus

            if (score <= 0f) {
                null
            } else {
                EdgeSearchResult(
                    chunk = chunk,
                    score = score
                )
            }
        }
            .sortedWith(
                compareByDescending<EdgeSearchResult> {
                    it.score
                }
                    .thenBy { it.chunk.id }
            )
            .take(topK)
    }

    private fun tokens(
        text: String
    ): List<String> {
        return text.lowercase()
            .split(
                Regex("[^\\p{L}\\p{N}]+")
            )
            .filter { it.isNotEmpty() }
    }
}

internal object EdgeHybridRankFusion {
    fun fuse(
        vector: List<EdgeSearchResult>,
        lexical: List<EdgeSearchResult>,
        topK: Int,
        rrfK: Float = 60f
    ): List<EdgeSearchResult> {
        if (topK <= 0) return emptyList()

        val chunks =
            linkedMapOf<String, EdgeChunk>()
        val scores =
            linkedMapOf<String, Float>()

        add(
            results = vector,
            scores = scores,
            chunks = chunks,
            rrfK = rrfK
        )
        add(
            results = lexical,
            scores = scores,
            chunks = chunks,
            rrfK = rrfK
        )

        val maximumScore =
            2f / (rrfK + 1f)

        return scores.mapNotNull { (id, score) ->
            chunks[id]?.let { chunk ->
                EdgeSearchResult(
                    chunk = chunk,
                    score =
                        score / maximumScore
                )
            }
        }
            .sortedWith(
                compareByDescending<EdgeSearchResult> {
                    it.score
                }
                    .thenBy { it.chunk.id }
            )
            .take(topK)
    }

    private fun add(
        results: List<EdgeSearchResult>,
        scores: MutableMap<String, Float>,
        chunks: MutableMap<String, EdgeChunk>,
        rrfK: Float
    ) {
        results.forEachIndexed { index, result ->
            val id = result.chunk.id
            chunks[id] = result.chunk
            scores[id] =
                (scores[id] ?: 0f) +
                    1f / (
                        rrfK +
                            (index + 1).toFloat()
                    )
        }
    }
}
