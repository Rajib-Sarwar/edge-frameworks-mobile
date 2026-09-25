package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgeCollectionRagTest {
    @Test
    fun collectionScopedRetrievalDoesNotLeakAcrossCollections() = runTest {
        val store = EdgeInMemoryVectorStore()
        val retriever = EdgeRetriever(
            embeddingProvider = CollectionKeywordEmbeddingProvider(),
            vectorStore = store
        )

        val travel = EdgeKnowledgeCollection(
            id = "travel",
            name = "Travel"
        )

        val work = EdgeKnowledgeCollection(
            id = "work",
            name = "Work"
        )

        retriever.index(
            document = EdgeDocument(
                id = "travel-note",
                text = "Tokyo flight leaves Newark at 9:30 AM."
            ),
            collection = travel
        )

        retriever.index(
            document = EdgeDocument(
                id = "work-note",
                text = "Project flight review is scheduled for Monday."
            ),
            collection = work
        )

        val results = retriever.retrieve(
            query = "flight",
            collection = travel,
            topK = 5
        )

        assertEquals(1, results.size)
        assertEquals(
            "travel-note",
            results.first().chunk.documentId
        )
        assertEquals(
            "travel",
            results.first().chunk.metadata["collectionID"]
        )
    }

    @Test
    fun reindexReplacesExistingDocumentChunks() = runTest {
        val store = EdgeInMemoryVectorStore()
        val retriever = EdgeRetriever(
            embeddingProvider = CollectionKeywordEmbeddingProvider(),
            vectorStore = store
        )

        val collection = EdgeKnowledgeCollection(
            id = "notes",
            name = "Notes"
        )

        retriever.index(
            document = EdgeDocument(
                id = "plan",
                text = "Tokyo flight leaves at 9:30 AM."
            ),
            collection = collection
        )

        retriever.reindex(
            document = EdgeDocument(
                id = "plan",
                text = "Dinner reservation is at 7 PM."
            ),
            collection = collection
        )

        val results = retriever.retrieve(
            query = "Tokyo flight",
            collection = collection,
            topK = 5
        )

        assertEquals(1, results.size)
        assertEquals(
            "Dinner reservation is at 7 PM.",
            results.first().chunk.text
        )
    }

    @Test
    fun clearCollectionRemovesOnlyMatchingCollection() = runTest {
        val store = EdgeInMemoryVectorStore()
        val retriever = EdgeRetriever(
            embeddingProvider = CollectionKeywordEmbeddingProvider(),
            vectorStore = store
        )

        val first = EdgeKnowledgeCollection(
            id = "first",
            name = "First"
        )

        val second = EdgeKnowledgeCollection(
            id = "second",
            name = "Second"
        )

        retriever.index(
            document = EdgeDocument(
                id = "one",
                text = "Tokyo flight."
            ),
            collection = first
        )

        retriever.index(
            document = EdgeDocument(
                id = "two",
                text = "Tokyo hotel."
            ),
            collection = second
        )

        val removed = retriever.clear(first)
        assertEquals(1, removed)

        val firstResults = retriever.retrieve(
            query = "Tokyo",
            collection = first,
            topK = 5
        )

        val secondResults = retriever.retrieve(
            query = "Tokyo",
            collection = second,
            topK = 5
        )

        assertTrue(firstResults.isEmpty())
        assertEquals(1, secondResults.size)
    }
}

private class CollectionKeywordEmbeddingProvider : EdgeEmbeddingProvider {
    override suspend fun embed(text: String): EdgeEmbedding {
        val normalized = text.lowercase()

        val travel = if (
            "tokyo" in normalized ||
            "flight" in normalized ||
            "hotel" in normalized
        ) 1f else 0f

        val food = if (
            "dinner" in normalized ||
            "reservation" in normalized
        ) 1f else 0f

        return EdgeEmbedding(
            values = listOf(travel, food)
        )
    }
}
