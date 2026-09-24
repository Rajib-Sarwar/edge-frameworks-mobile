package io.github.rajibsarwar.edgeframeworks

interface EdgeVectorStore {
    suspend fun upsert(
        chunks: List<EdgeChunk>,
        embeddings: List<EdgeEmbedding>
    )

    suspend fun search(
        query: EdgeEmbedding,
        topK: Int
    ): List<EdgeSearchResult>

    suspend fun removeAll()
}
