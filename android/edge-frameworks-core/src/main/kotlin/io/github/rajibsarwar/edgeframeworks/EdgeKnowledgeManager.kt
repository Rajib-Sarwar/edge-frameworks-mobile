package io.github.rajibsarwar.edgeframeworks

class EdgeKnowledgeManager(
    private val catalog: EdgeKnowledgeCatalog,
    private val indexer: EdgeIncrementalIndexer
) {
    suspend fun collections():
        List<EdgeKnowledgeCollectionSummary> {
        val collections = catalog.collections()
        val sources = catalog.sources()

        return collections.map { collection ->
            val matching = sources.filter {
                it.collectionId == collection.id
            }

            EdgeKnowledgeCollectionSummary(
                collection = collection,
                sourceCount = matching.size,
                documentCount =
                    matching.sumOf {
                        it.documentIds.size
                    },
                lastIndexedAtMilliseconds =
                    matching.maxOfOrNull {
                        it.indexedAtMilliseconds
                    }
            )
        }
    }

    suspend fun collection(
        id: String
    ): EdgeKnowledgeCollection? {
        return catalog.collection(id)
    }

    suspend fun upsert(
        collection: EdgeKnowledgeCollection
    ) {
        catalog.upsert(collection)
    }

    suspend fun sources(
        collectionId: String? = null
    ): List<EdgeKnowledgeSource> {
        return catalog.sources(
            collectionId
        )
    }

    suspend fun source(
        id: String
    ): EdgeKnowledgeSource? {
        return catalog.source(id)
    }

    suspend fun syncSource(
        sourceId: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documents: List<EdgeDocument>,
        collection: EdgeKnowledgeCollection,
        metadata: Map<String, String> =
            emptyMap(),
        chunker: EdgeTextChunker =
            EdgeTextChunker()
    ): EdgeSourceSyncResult {
        return indexer.sync(
            sourceId = sourceId,
            sourceIdentifier = sourceIdentifier,
            contentFingerprint =
                contentFingerprint,
            documents = documents,
            collection = collection,
            metadata = metadata,
            chunker = chunker
        )
    }

    suspend fun removeSource(
        id: String
    ): Int {
        return indexer.removeSource(id)
    }

    suspend fun removeCollection(
        id: String
    ): Int {
        val collection =
            catalog.collection(id)
                ?: throw EdgeKnowledgeManagerException
                    .CollectionNotFound(id)

        return indexer.removeCollection(
            collection
        )
    }
}
