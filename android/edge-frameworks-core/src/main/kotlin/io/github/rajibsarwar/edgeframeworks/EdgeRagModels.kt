package io.github.rajibsarwar.edgeframeworks

data class EdgeDocument(
    val id: String,
    val text: String,
    val metadata: Map<String, String> = emptyMap()
)

data class EdgeChunk(
    val id: String,
    val documentId: String,
    val text: String,
    val metadata: Map<String, String> = emptyMap()
)

data class EdgeEmbedding(
    val values: List<Float>
)

data class EdgeSearchResult(
    val chunk: EdgeChunk,
    val score: Float
)

sealed class EdgeVectorException(message: String) : Exception(message) {
    data class DimensionMismatch(
        val expected: Int,
        val actual: Int
    ) : EdgeVectorException(
        "Embedding dimension mismatch: expected $expected, got $actual"
    )

    data class CountMismatch(
        val expected: Int,
        val actual: Int
    ) : EdgeVectorException(
        "Item count mismatch: expected $expected, got $actual"
    )

    data object ZeroMagnitude :
        EdgeVectorException("Cosine similarity is undefined for a zero-magnitude vector")
}
