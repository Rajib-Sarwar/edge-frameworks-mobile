package io.github.rajibsarwar.edgeframeworks

data class EdgeRAGRequest(
    val query: String,
    val collection: EdgeKnowledgeCollection? = null,
    val filter: EdgeVectorFilter? = null,
    val topK: Int = 3,
    val minimumScore: Float? = null,
    val retrievalMode: EdgeRetrievalMode =
        EdgeRetrievalMode.VECTOR,
    val systemPrompt: String? = null
)

data class EdgeRAGResult(
    val answer: String,
    val retrievedResults: List<EdgeSearchResult>,
    val context: String,
    val metrics: EdgeRAGMetrics? = null
)
