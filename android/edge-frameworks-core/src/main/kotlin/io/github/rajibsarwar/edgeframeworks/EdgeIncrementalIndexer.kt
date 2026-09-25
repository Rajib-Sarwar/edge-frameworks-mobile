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

        if (
            existing != null &&
            existing.collectionId == collection.id &&
            existing.documentStates.isNotEmpty()
        ) {
            return syncFineGrained(
                existing = existing,
                sourceId = sourceId,
                sourceIdentifier = sourceIdentifier,
                contentFingerprint = contentFingerprint,
                documents = documents,
                collection = collection,
                metadata = metadata,
                chunker = chunker
            )
        }

        return replaceWholeSource(
            existing = existing,
            sourceId = sourceId,
            sourceIdentifier = sourceIdentifier,
            contentFingerprint = contentFingerprint,
            documents = documents,
            collection = collection,
            metadata = metadata,
            chunker = chunker
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

    private suspend fun syncFineGrained(
        existing: EdgeKnowledgeSource,
        sourceId: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documents: List<EdgeDocument>,
        collection: EdgeKnowledgeCollection,
        metadata: Map<String, String>,
        chunker: EdgeTextChunker
    ): EdgeSourceSyncResult {
        val previousByKey =
            existing.documentStates
                .associateBy { it.key }

        val incoming =
            documents.mapIndexed {
                index,
                document ->

                IncomingDocument(
                    document = document,
                    key = documentKey(
                        document = document,
                        index = index
                    ),
                    fingerprint =
                        documentFingerprint(
                            document
                        )
                )
            }

        val incomingKeys =
            incoming.map { it.key }.toSet()

        var removedChunkCount = 0
        var indexedDocumentCount = 0
        val nextStates =
            mutableListOf<EdgeSourceDocumentState>()

        for (oldState in existing.documentStates) {
            if (oldState.key in incomingKeys) {
                continue
            }

            coroutineContext.ensureActive()
            removedChunkCount += retriever.remove(
                documentId = oldState.documentId,
                collectionId = existing.collectionId
            )
        }

        for (item in incoming) {
            coroutineContext.ensureActive()

            val previous =
                previousByKey[item.key]

            if (
                previous != null &&
                previous.contentFingerprint ==
                    item.fingerprint
            ) {
                nextStates += previous
                continue
            }

            if (previous != null) {
                removedChunkCount += retriever.remove(
                    documentId = previous.documentId,
                    collectionId = existing.collectionId
                )
            }

            retriever.index(
                document = item.document,
                collection = collection,
                chunker = chunker
            )

            indexedDocumentCount += 1
            nextStates += EdgeSourceDocumentState(
                key = item.key,
                documentId = item.document.id,
                contentFingerprint =
                    item.fingerprint
            )
        }

        val source = EdgeKnowledgeSource(
            id = sourceId,
            collectionId = collection.id,
            sourceIdentifier = sourceIdentifier,
            contentFingerprint = contentFingerprint,
            documentIds =
                nextStates.map {
                    it.documentId
                },
            documentStates = nextStates,
            metadata = metadata
        )

        catalog.upsert(collection)
        catalog.upsert(source)

        return EdgeSourceSyncResult.Indexed(
            source = source,
            removedChunkCount =
                removedChunkCount,
            indexedDocumentCount =
                indexedDocumentCount
        )
    }

    private suspend fun replaceWholeSource(
        existing: EdgeKnowledgeSource?,
        sourceId: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documents: List<EdgeDocument>,
        collection: EdgeKnowledgeCollection,
        metadata: Map<String, String>,
        chunker: EdgeTextChunker
    ): EdgeSourceSyncResult {
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

        val states =
            mutableListOf<EdgeSourceDocumentState>()

        documents.forEachIndexed {
            index,
            document ->

            coroutineContext.ensureActive()

            retriever.index(
                document = document,
                collection = collection,
                chunker = chunker
            )

            states += EdgeSourceDocumentState(
                key = documentKey(
                    document = document,
                    index = index
                ),
                documentId = document.id,
                contentFingerprint =
                    documentFingerprint(
                        document
                    )
            )
        }

        val source = EdgeKnowledgeSource(
            id = sourceId,
            collectionId = collection.id,
            sourceIdentifier = sourceIdentifier,
            contentFingerprint = contentFingerprint,
            documentIds =
                states.map {
                    it.documentId
                },
            documentStates = states,
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

    private fun documentKey(
        document: EdgeDocument,
        index: Int
    ): String {
        document.metadata["pageNumber"]
            ?.let {
                return "page:$it"
            }

        document.metadata["sourceSectionID"]
            ?.let {
                return "section:$it"
            }

        return "index:$index"
    }

    private fun documentFingerprint(
        document: EdgeDocument
    ): String {
        val metadata =
            document.metadata
                .filterKeys {
                    it != "parentDocumentID"
                }
                .toSortedMap()
                .entries
                .joinToString("\n") {
                    "${it.key}=${it.value}"
                }

        return EdgeContentFingerprint.sha256(
            """
            ${document.text}
            ---
            $metadata
            """.trimIndent()
        )
    }

    private data class IncomingDocument(
        val document: EdgeDocument,
        val key: String,
        val fingerprint: String
    )
}
