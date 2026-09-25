package io.github.rajibsarwar.edgeframeworks

interface EdgeVectorStore {
    suspend fun upsert(
        chunks: List<EdgeChunk>,
        embeddings: List<EdgeEmbedding>
    )

    suspend fun search(
        query: EdgeEmbedding,
        topK: Int,
        filter: EdgeVectorFilter? = null
    ): List<EdgeSearchResult>

    suspend fun remove(
        filter: EdgeVectorFilter
    ): Int

    suspend fun removeAll()
}
