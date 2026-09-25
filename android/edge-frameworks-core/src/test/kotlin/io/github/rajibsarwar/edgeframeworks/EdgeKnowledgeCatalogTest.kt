package io.github.rajibsarwar.edgeframeworks

import java.io.File
import java.util.concurrent.atomic.AtomicInteger
import kotlin.io.path.createTempDirectory
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgeKnowledgeCatalogTest {
    @Test
    fun fileCatalogPersistsCollectionsAndSources() = runTest {
        val directory = createTempDirectory(
            prefix = "edge-catalog-"
        ).toFile()
        val file = File(
            directory,
            "catalog.bin"
        )

        val catalog =
            EdgeFileKnowledgeCatalog(file)

        val collection =
            EdgeKnowledgeCollection(
                id = "travel",
                name = "Travel",
                metadata = mapOf(
                    "kind" to "personal"
                )
            )

        val source = EdgeKnowledgeSource(
            id = "trip-file",
            collectionId = collection.id,
            sourceIdentifier = "trip.pdf",
            contentFingerprint = "abc123",
            documentIds = listOf(
                "trip-page-1"
            ),
            metadata = mapOf(
                "format" to "pdf"
            ),
            indexedAtMilliseconds = 42
        )

        catalog.upsert(collection)
        catalog.upsert(source)

        val reopened =
            EdgeFileKnowledgeCatalog(file)

        assertEquals(
            collection,
            reopened.collection("travel")
        )
        assertEquals(
            source,
            reopened.source("trip-file")
        )

        directory.deleteRecursively()
    }

    @Test
    fun incrementalIndexerSkipsUnchangedSourceAndReindexesChangedSource() =
        runTest {
            val embeddingProvider =
                CountingEmbeddingProvider()

            val store =
                EdgeInMemoryVectorStore()

            val retriever = EdgeRetriever(
                embeddingProvider =
                    embeddingProvider,
                vectorStore = store
            )

            val directory =
                createTempDirectory(
                    prefix = "edge-indexer-"
                ).toFile()

            val catalog =
                EdgeFileKnowledgeCatalog(
                    File(
                        directory,
                        "catalog.bin"
                    )
                )

            val indexer =
                EdgeIncrementalIndexer(
                    retriever = retriever,
                    catalog = catalog
                )

            val collection =
                EdgeKnowledgeCollection(
                    id = "notes",
                    name = "Notes"
                )

            val first = EdgeDocument(
                id = "source-document",
                text =
                    "Tokyo flight leaves at 9:30 AM."
            )

            val firstResult =
                indexer.sync(
                    sourceId = "source-1",
                    sourceIdentifier =
                        "notes.txt",
                    contentFingerprint =
                        EdgeContentFingerprint.sha256(
                            first.text
                        ),
                    documents = listOf(first),
                    collection = collection
                )

            assertTrue(
                firstResult is
                    EdgeSourceSyncResult.Indexed
            )
            assertEquals(
                1,
                embeddingProvider.callCount.get()
            )

            val unchanged =
                indexer.sync(
                    sourceId = "source-1",
                    sourceIdentifier =
                        "notes.txt",
                    contentFingerprint =
                        EdgeContentFingerprint.sha256(
                            first.text
                        ),
                    documents = listOf(
                        EdgeDocument(
                            id =
                                "source-document",
                            text =
                                "This should not be embedded."
                        )
                    ),
                    collection = collection
                )

            assertTrue(
                unchanged is
                    EdgeSourceSyncResult.Unchanged
            )
            assertEquals(
                1,
                embeddingProvider.callCount.get()
            )

            val changed = EdgeDocument(
                id = "source-document",
                text =
                    "Dinner reservation is at 7 PM."
            )

            val changedResult =
                indexer.sync(
                    sourceId = "source-1",
                    sourceIdentifier =
                        "notes.txt",
                    contentFingerprint =
                        EdgeContentFingerprint.sha256(
                            changed.text
                        ),
                    documents =
                        listOf(changed),
                    collection = collection
                )

            assertTrue(
                changedResult is
                    EdgeSourceSyncResult.Indexed
            )

            val indexed =
                changedResult as
                    EdgeSourceSyncResult.Indexed

            assertEquals(
                1,
                indexed.removedChunkCount
            )
            assertEquals(
                1,
                indexed.indexedDocumentCount
            )
            assertEquals(
                2,
                embeddingProvider.callCount.get()
            )

            val results =
                retriever.retrieve(
                    query = "anything",
                    collection = collection,
                    topK = 5
                )

            assertEquals(
                1,
                results.size
            )
            assertEquals(
                changed.text,
                results.first().chunk.text
            )

            directory.deleteRecursively()
        }
    @Test
    fun fineGrainedSyncOnlyReembedsChangedPage() = runTest {
        val embeddingProvider =
            CountingEmbeddingProvider()

        val retriever = EdgeRetriever(
            embeddingProvider = embeddingProvider,
            vectorStore = EdgeInMemoryVectorStore()
        )

        val directory =
            createTempDirectory(
                prefix = "edge-fine-indexer-"
            ).toFile()

        val catalog =
            EdgeFileKnowledgeCatalog(
                File(
                    directory,
                    "catalog.bin"
                )
            )

        val indexer = EdgeIncrementalIndexer(
            retriever = retriever,
            catalog = catalog
        )

        val collection =
            EdgeKnowledgeCollection(
                id = "manual",
                name = "Manual"
            )

        val firstDocuments = listOf(
            EdgeDocument(
                id = "old-page-1",
                text = "Page one stays exactly the same.",
                metadata = mapOf(
                    "source" to "manual.pdf",
                    "pageNumber" to "1",
                    "parentDocumentID" to "old-parent"
                )
            ),
            EdgeDocument(
                id = "old-page-2",
                text = "Page two old content.",
                metadata = mapOf(
                    "source" to "manual.pdf",
                    "pageNumber" to "2",
                    "parentDocumentID" to "old-parent"
                )
            )
        )

        indexer.sync(
            sourceId = "manual-source",
            sourceIdentifier = "manual.pdf",
            contentFingerprint = "whole-v1",
            documents = firstDocuments,
            collection = collection
        )

        assertEquals(
            2,
            embeddingProvider.callCount.get()
        )

        val secondDocuments = listOf(
            EdgeDocument(
                id = "new-page-1",
                text = "Page one stays exactly the same.",
                metadata = mapOf(
                    "source" to "manual.pdf",
                    "pageNumber" to "1",
                    "parentDocumentID" to "new-parent"
                )
            ),
            EdgeDocument(
                id = "new-page-2",
                text = "Page two changed content.",
                metadata = mapOf(
                    "source" to "manual.pdf",
                    "pageNumber" to "2",
                    "parentDocumentID" to "new-parent"
                )
            )
        )

        val result = indexer.sync(
            sourceId = "manual-source",
            sourceIdentifier = "manual.pdf",
            contentFingerprint = "whole-v2",
            documents = secondDocuments,
            collection = collection
        )

        assertTrue(
            result is EdgeSourceSyncResult.Indexed
        )

        val indexed =
            result as EdgeSourceSyncResult.Indexed

        assertEquals(
            1,
            indexed.removedChunkCount
        )
        assertEquals(
            1,
            indexed.indexedDocumentCount
        )
        assertEquals(
            "old-page-1",
            indexed.source.documentStates
                .first {
                    it.key == "page:1"
                }
                .documentId
        )
        assertEquals(
            "new-page-2",
            indexed.source.documentStates
                .first {
                    it.key == "page:2"
                }
                .documentId
        )
        assertEquals(
            3,
            embeddingProvider.callCount.get()
        )

        directory.deleteRecursively()
    }

}

private class CountingEmbeddingProvider :
    EdgeEmbeddingProvider {
    val callCount = AtomicInteger(0)

    override suspend fun embed(
        text: String
    ): EdgeEmbedding {
        callCount.incrementAndGet()
        return EdgeEmbedding(
            values = listOf(1f, 1f)
        )
    }
}
