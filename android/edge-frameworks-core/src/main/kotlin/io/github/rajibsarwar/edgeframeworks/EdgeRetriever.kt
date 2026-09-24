package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.ensureActive
import kotlin.coroutines.coroutineContext

class EdgeRetriever(
    private val embeddingProvider: EdgeEmbeddingProvider,
    private val vectorStore: EdgeVectorStore
) {
    suspend fun index(
        document: EdgeDocument,
        chunker: EdgeTextChunker = EdgeTextChunker()
    ) {
        index(
            chunker.chunk(document)
        )
    }

    suspend fun index(chunks: List<EdgeChunk>) {
        val embeddings = buildList {
            for (chunk in chunks) {
                coroutineContext.ensureActive()
                add(embeddingProvider.embed(chunk.text))
            }
        }

        vectorStore.upsert(
            chunks = chunks,
            embeddings = embeddings
        )
    }

    suspend fun retrieve(
        query: String,
        topK: Int = 3
    ): List<EdgeSearchResult> {
        coroutineContext.ensureActive()

        val queryEmbedding = embeddingProvider.embed(query)

        return vectorStore.search(
            query = queryEmbedding,
            topK = topK
        )
    }
}
