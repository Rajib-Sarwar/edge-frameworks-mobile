package io.github.rajibsarwar.edgeframeworks

data class EdgeRetrievalMetrics(
    val embeddingMilliseconds: Double,
    val searchMilliseconds: Double,
    val totalMilliseconds: Double,
    val resultCount: Int,
    val topScore: Float?,
    val bottomScore: Float?
)

data class EdgeMeasuredRetrieval(
    val results: List<EdgeSearchResult>,
    val metrics: EdgeRetrievalMetrics
)

data class EdgeRAGMetrics(
    val retrieval: EdgeRetrievalMetrics,
    val generationMilliseconds: Double,
    val totalMilliseconds: Double,
    val requestedTopK: Int,
    val retainedResultCount: Int,
    val contextCharacterCount: Int
)
