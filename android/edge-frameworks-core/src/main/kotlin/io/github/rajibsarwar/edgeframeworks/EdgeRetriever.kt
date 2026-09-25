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
        return retrieveMeasured(
            query = query,
            filter = filter,
            topK = topK
        ).results
    }

    suspend fun retrieveMeasured(
        query: String,
        filter: EdgeVectorFilter? = null,
        topK: Int = 3
    ): EdgeMeasuredRetrieval {
        coroutineContext.ensureActive()

        val totalStart = System.nanoTime()
        val embeddingStart = totalStart

        val queryEmbedding =
            embeddingProvider.embed(query)

        val embeddingEnd = System.nanoTime()

        coroutineContext.ensureActive()

        val results = vectorStore.search(
            query = queryEmbedding,
            topK = topK,
            filter = filter
        )

        val searchEnd = System.nanoTime()

        return EdgeMeasuredRetrieval(
            results = results,
            metrics = EdgeRetrievalMetrics(
                embeddingMilliseconds =
                    milliseconds(
                        embeddingStart,
                        embeddingEnd
                    ),
                searchMilliseconds =
                    milliseconds(
                        embeddingEnd,
                        searchEnd
                    ),
                totalMilliseconds =
                    milliseconds(
                        totalStart,
                        searchEnd
                    ),
                resultCount = results.size,
                topScore =
                    results.firstOrNull()?.score,
                bottomScore =
                    results.lastOrNull()?.score
            )
        )
    }

    suspend fun remove(
        documentId: String,
        collection: EdgeKnowledgeCollection? = null
    ): Int {
        return remove(
            documentId = documentId,
            collectionId = collection?.id
        )
    }

    suspend fun remove(
        documentId: String,
        collectionId: String?
    ): Int {
        return vectorStore.remove(
            EdgeVectorFilter(
                documentId = documentId,
                collectionId = collectionId
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

    private fun milliseconds(
        start: Long,
        end: Long
    ): Double {
        return (end - start) / 1_000_000.0
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
