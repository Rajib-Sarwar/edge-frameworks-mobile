package io.github.rajibsarwar.edgeframeworks

interface EdgeEmbeddingProvider {
    suspend fun embed(text: String): EdgeEmbedding
}
