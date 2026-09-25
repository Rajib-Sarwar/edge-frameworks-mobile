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

    suspend fun index(
        document: EdgeDocument,
        collection: EdgeKnowledgeCollection,
        chunker: EdgeTextChunker = EdgeTextChunker()
    ) {
        index(
            documentForCollection(
                document = document,
                collection = collection
            ),
            chunker = chunker
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

    suspend fun reindex(
        document: EdgeDocument,
        collection: EdgeKnowledgeCollection,
        chunker: EdgeTextChunker = EdgeTextChunker()
    ) {
        remove(
            documentId = document.id,
            collection = collection
        )

        index(
            document = document,
            collection = collection,
            chunker = chunker
        )
    }

    suspend fun retrieve(
        query: String,
        topK: Int = 3
    ): List<EdgeSearchResult> {
        return retrieve(
            query = query,
            filter = null,
            topK = topK
        )
    }

    suspend fun retrieve(
        query: String,
        collection: EdgeKnowledgeCollection,
        topK: Int = 3
    ): List<EdgeSearchResult> {
        return retrieve(
            query = query,
            filter = EdgeVectorFilter(
                collectionId = collection.id
            ),
            topK = topK
        )
    }

    suspend fun retrieve(
        query: String,
        filter: EdgeVectorFilter?,
        topK: Int = 3
    ): List<EdgeSearchResult> {
        coroutineContext.ensureActive()

        val queryEmbedding = embeddingProvider.embed(query)

        return vectorStore.search(
            query = queryEmbedding,
            topK = topK,
            filter = filter
        )
    }

    suspend fun remove(
        documentId: String,
        collection: EdgeKnowledgeCollection? = null
    ): Int {
        return vectorStore.remove(
            EdgeVectorFilter(
                documentId = documentId,
                collectionId = collection?.id
            )
        )
    }

    suspend fun remove(
        metadata: Map<String, String>,
        collection: EdgeKnowledgeCollection? = null
    ): Int {
        return vectorStore.remove(
            EdgeVectorFilter(
                collectionId = collection?.id,
                metadata = metadata
            )
        )
    }

    suspend fun clear(
        collection: EdgeKnowledgeCollection
    ): Int {
        return vectorStore.remove(
            EdgeVectorFilter(
                collectionId = collection.id
            )
        )
    }

    private fun documentForCollection(
        document: EdgeDocument,
        collection: EdgeKnowledgeCollection
    ): EdgeDocument {
        val metadata = collection.metadata
            .toMutableMap()
            .apply {
                putAll(document.metadata)
                this["collectionID"] = collection.id
                this["collectionName"] = collection.name
            }

        return EdgeDocument(
            id = document.id,
            text = document.text,
            metadata = metadata
        )
    }
}
