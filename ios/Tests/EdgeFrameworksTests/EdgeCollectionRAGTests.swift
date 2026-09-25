import XCTest
@testable import EdgeFrameworks

final class EdgeCollectionRAGTests: XCTestCase {
    func testCollectionScopedRetrievalDoesNotLeakAcrossCollections() async throws {
        let store = EdgeInMemoryVectorStore()
        let retriever = EdgeRetriever(
            embeddingProvider: CollectionKeywordEmbeddingProvider(),
            vectorStore: store
        )

        let travel = EdgeKnowledgeCollection(
            id: "travel",
            name: "Travel"
        )

        let work = EdgeKnowledgeCollection(
            id: "work",
            name: "Work"
        )

        try await retriever.index(
            EdgeDocument(
                id: "travel-note",
                text: "Tokyo flight leaves Newark at 9:30 AM."
            ),
            in: travel
        )

        try await retriever.index(
            EdgeDocument(
                id: "work-note",
                text: "Project flight review is scheduled for Monday."
            ),
            in: work
        )

        let results = try await retriever.retrieve(
            query: "flight",
            in: travel,
            topK: 5
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(
            results.first?.chunk.documentID,
            "travel-note"
        )
        XCTAssertEqual(
            results.first?.chunk.metadata["collectionID"],
            "travel"
        )
    }

    func testReindexReplacesExistingDocumentChunks() async throws {
        let store = EdgeInMemoryVectorStore()
        let retriever = EdgeRetriever(
            embeddingProvider: CollectionKeywordEmbeddingProvider(),
            vectorStore: store
        )

        let collection = EdgeKnowledgeCollection(
            id: "notes",
            name: "Notes"
        )

        try await retriever.index(
            EdgeDocument(
                id: "plan",
                text: "Tokyo flight leaves at 9:30 AM."
            ),
            in: collection
        )

        try await retriever.reindex(
            EdgeDocument(
                id: "plan",
                text: "Dinner reservation is at 7 PM."
            ),
            in: collection
        )

        let travelResults = try await retriever.retrieve(
            query: "Tokyo flight",
            in: collection,
            topK: 5
        )

        XCTAssertEqual(travelResults.count, 1)
        XCTAssertEqual(
            travelResults.first?.chunk.text,
            "Dinner reservation is at 7 PM."
        )
    }

    func testClearCollectionRemovesOnlyMatchingCollection() async throws {
        let store = EdgeInMemoryVectorStore()
        let retriever = EdgeRetriever(
            embeddingProvider: CollectionKeywordEmbeddingProvider(),
            vectorStore: store
        )

        let first = EdgeKnowledgeCollection(
            id: "first",
            name: "First"
        )

        let second = EdgeKnowledgeCollection(
            id: "second",
            name: "Second"
        )

        try await retriever.index(
            EdgeDocument(
                id: "one",
                text: "Tokyo flight."
            ),
            in: first
        )

        try await retriever.index(
            EdgeDocument(
                id: "two",
                text: "Tokyo hotel."
            ),
            in: second
        )

        let removed = try await retriever.clear(first)
        XCTAssertEqual(removed, 1)

        let firstResults = try await retriever.retrieve(
            query: "Tokyo",
            in: first,
            topK: 5
        )

        let secondResults = try await retriever.retrieve(
            query: "Tokyo",
            in: second,
            topK: 5
        )

        XCTAssertTrue(firstResults.isEmpty)
        XCTAssertEqual(secondResults.count, 1)
    }
}

private struct CollectionKeywordEmbeddingProvider: EdgeEmbeddingProvider {
    func embed(_ text: String) async throws -> EdgeEmbedding {
        let normalized = text.lowercased()

        let travel: Float = (
            normalized.contains("tokyo") ||
            normalized.contains("flight") ||
            normalized.contains("hotel")
        ) ? 1 : 0

        let food: Float = (
            normalized.contains("dinner") ||
            normalized.contains("reservation")
        ) ? 1 : 0

        return EdgeEmbedding(
            values: [travel, food]
        )
    }
}
