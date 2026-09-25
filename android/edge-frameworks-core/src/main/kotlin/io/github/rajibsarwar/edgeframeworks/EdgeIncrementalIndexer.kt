package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.ensureActive
import kotlin.coroutines.coroutineContext

class EdgeIncrementalIndexer(
    private val retriever: EdgeRetriever,
    private val catalog: EdgeKnowledgeCatalog
) {
    suspend fun sync(
        sourceId: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documents: List<EdgeDocument>,
        collection: EdgeKnowledgeCollection,
        metadata: Map<String, String> = emptyMap(),
        chunker: EdgeTextChunker = EdgeTextChunker()
    ): EdgeSourceSyncResult {
        coroutineContext.ensureActive()

        val existing = catalog.source(sourceId)

        if (
            existing != null &&
            existing.collectionId == collection.id &&
            existing.contentFingerprint ==
                contentFingerprint
        ) {
            return EdgeSourceSyncResult.Unchanged(
                existing
            )
        }

        var removedChunkCount = 0

        if (existing != null) {
            for (documentId in existing.documentIds) {
                coroutineContext.ensureActive()
                removedChunkCount += retriever.remove(
                    documentId = documentId,
                    collectionId = existing.collectionId
                )
            }
        }

        for (document in documents) {
            coroutineContext.ensureActive()
            retriever.index(
                document = document,
                collection = collection,
                chunker = chunker
            )
        }

        val source = EdgeKnowledgeSource(
            id = sourceId,
            collectionId = collection.id,
            sourceIdentifier = sourceIdentifier,
            contentFingerprint = contentFingerprint,
            documentIds = documents.map { it.id },
            metadata = metadata
        )

        catalog.upsert(collection)
        catalog.upsert(source)

        return EdgeSourceSyncResult.Indexed(
            source = source,
            removedChunkCount =
                removedChunkCount,
            indexedDocumentCount =
                documents.size
        )
    }

    suspend fun removeSource(
        id: String
    ): Int {
        val source = catalog.source(id)
            ?: return 0

        var removed = 0

        for (documentId in source.documentIds) {
            coroutineContext.ensureActive()
            removed += retriever.remove(
                documentId = documentId,
                collectionId = source.collectionId
            )
        }

        catalog.removeSource(id)
        return removed
    }

    suspend fun removeCollection(
        collection: EdgeKnowledgeCollection
    ): Int {
        val removed =
            retriever.clear(collection)

        catalog.removeCollection(
            collection.id
        )

        return removed
    }
}
