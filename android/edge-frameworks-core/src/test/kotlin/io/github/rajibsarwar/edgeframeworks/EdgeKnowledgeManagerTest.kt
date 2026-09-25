package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgeKnowledgeManagerTest {
    @Test
    fun collectionSummariesReflectSourcesAndDocuments() = runTest {
        val retriever = EdgeRetriever(
            embeddingProvider =
                ManagerEmbeddingProvider(),
            vectorStore =
                EdgeInMemoryVectorStore()
        )

        val catalog = ManagerCatalog()
        val manager = EdgeKnowledgeManager(
            catalog = catalog,
            indexer = EdgeIncrementalIndexer(
                retriever = retriever,
                catalog = catalog
            )
        )

        val collection =
            EdgeKnowledgeCollection(
                id = "asset-1",
                name = "Rooftop Unit"
            )

        manager.syncSource(
            sourceId = "manual",
            sourceIdentifier = "manual.pdf",
            contentFingerprint = "v1",
            documents = listOf(
                EdgeDocument(
                    id = "page-1",
                    text =
                        "Compressor troubleshooting.",
                    metadata = mapOf(
                        "pageNumber" to "1"
                    )
                ),
                EdgeDocument(
                    id = "page-2",
                    text = "Control board wiring.",
                    metadata = mapOf(
                        "pageNumber" to "2"
                    )
                )
            ),
            collection = collection
        )

        val summaries = manager.collections()

        assertEquals(1, summaries.size)
        assertEquals(
            "asset-1",
            summaries.first()
                .collection
                .id
        )
        assertEquals(
            1,
            summaries.first()
                .sourceCount
        )
        assertEquals(
            2,
            summaries.first()
                .documentCount
        )
        assertNotNull(
            summaries.first()
                .lastIndexedAtMilliseconds
        )
    }

    @Test
    fun removeCollectionByIdentifierRemovesCatalogAndVectors() = runTest {
        val catalog = ManagerCatalog()
        val manager = EdgeKnowledgeManager(
            catalog = catalog,
            indexer = EdgeIncrementalIndexer(
                retriever = EdgeRetriever(
                    embeddingProvider =
                        ManagerEmbeddingProvider(),
                    vectorStore =
                        EdgeInMemoryVectorStore()
                ),
                catalog = catalog
            )
        )

        val collection =
            EdgeKnowledgeCollection(
                id = "asset-1",
                name = "Rooftop Unit"
            )

        manager.syncSource(
            sourceId = "manual",
            sourceIdentifier = "manual.pdf",
            contentFingerprint = "v1",
            documents = listOf(
                EdgeDocument(
                    id = "page-1",
                    text =
                        "Compressor troubleshooting."
                )
            ),
            collection = collection
        )

        val removed =
            manager.removeCollection(
                collection.id
            )

        assertEquals(1, removed)
        assertNull(
            manager.collection(
                collection.id
            )
        )
        assertTrue(
            manager.sources().isEmpty()
        )
    }
}

private class ManagerEmbeddingProvider :
    EdgeEmbeddingProvider {
    override suspend fun embed(
        text: String
    ): EdgeEmbedding {
        return EdgeEmbedding(
            values = listOf(1f, 1f)
        )
    }
}

private class ManagerCatalog :
    EdgeKnowledgeCatalog {
    private val collectionsById =
        linkedMapOf<String, EdgeKnowledgeCollection>()
    private val sourcesById =
        linkedMapOf<String, EdgeKnowledgeSource>()

    override suspend fun collections():
        List<EdgeKnowledgeCollection> {
        return collectionsById.values
            .sortedBy { it.id }
    }

    override suspend fun collection(
        id: String
    ): EdgeKnowledgeCollection? {
        return collectionsById[id]
    }

    override suspend fun upsert(
        collection: EdgeKnowledgeCollection
    ) {
        collectionsById[
            collection.id
        ] = collection
    }

    override suspend fun removeCollection(
        id: String
    ) {
        collectionsById.remove(id)
        sourcesById.entries.removeAll {
            it.value.collectionId == id
        }
    }

    override suspend fun sources(
        collectionId: String?
    ): List<EdgeKnowledgeSource> {
        return sourcesById.values
            .filter {
                collectionId == null ||
                it.collectionId ==
                    collectionId
            }
            .sortedBy { it.id }
    }

    override suspend fun source(
        id: String
    ): EdgeKnowledgeSource? {
        return sourcesById[id]
    }

    override suspend fun upsert(
        source: EdgeKnowledgeSource
    ) {
        sourcesById[
            source.id
        ] = source
    }

    override suspend fun removeSource(
        id: String
    ) {
        sourcesById.remove(id)
    }

    override suspend fun removeAll() {
        collectionsById.clear()
        sourcesById.clear()
    }
}
