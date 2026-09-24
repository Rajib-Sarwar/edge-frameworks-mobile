import XCTest
@testable import EdgeFrameworks

final class EdgeRAGTests: XCTestCase {
    func testCosineSimilarityRanksAlignedVectorsHigher() throws {
        let aligned = try EdgeVectorMath.cosineSimilarity(
            EdgeEmbedding(values: [1, 0]),
            EdgeEmbedding(values: [1, 0])
        )

        let orthogonal = try EdgeVectorMath.cosineSimilarity(
            EdgeEmbedding(values: [1, 0]),
            EdgeEmbedding(values: [0, 1])
        )

        XCTAssertEqual(aligned, 1, accuracy: 0.0001)
        XCTAssertEqual(orthogonal, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(aligned, orthogonal)
    }

    func testRetrieverIndexesAndReturnsMostRelevantChunk() async throws {
        let retriever = EdgeRetriever(
            embeddingProvider: KeywordEmbeddingProvider(),
            vectorStore: EdgeInMemoryVectorStore()
        )

        let chunks = [
            EdgeChunk(
                id: "travel",
                documentID: "notes",
                text: "Flight leaves Newark for Tokyo on October 12."
            ),
            EdgeChunk(
                id: "food",
                documentID: "notes",
                text: "Dinner reservation is at the Italian restaurant."
            )
        ]

        try await retriever.index(chunks)

        let results = try await retriever.retrieve(
            query: "When is my Japan flight?",
            topK: 1
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.chunk.id, "travel")
        XCTAssertGreaterThan(results.first?.score ?? 0, 0.9)
    }

    func testVectorStoreUpsertReplacesChunkByIdentifier() async throws {
        let store = EdgeInMemoryVectorStore()

        try await store.upsert(
            chunks: [
                EdgeChunk(
                    id: "same",
                    documentID: "doc",
                    text: "old"
                )
            ],
            embeddings: [
                EdgeEmbedding(values: [1, 0])
            ]
        )

        try await store.upsert(
            chunks: [
                EdgeChunk(
                    id: "same",
                    documentID: "doc",
                    text: "new"
                )
            ],
            embeddings: [
                EdgeEmbedding(values: [0, 1])
            ]
        )

        let results = try await store.search(
            query: EdgeEmbedding(values: [0, 1]),
            topK: 3
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.chunk.text, "new")
    }

    func testVectorStoreRejectsMismatchedItemCounts() async {
        let store = EdgeInMemoryVectorStore()

        do {
            try await store.upsert(
                chunks: [
                    EdgeChunk(
                        id: "one",
                        documentID: "doc",
                        text: "one"
                    )
                ],
                embeddings: []
            )
            XCTFail("Expected count mismatch")
        } catch {
            XCTAssertEqual(
                error as? EdgeVectorError,
                .countMismatch(expected: 1, actual: 0)
            )
        }
    }
}

private struct KeywordEmbeddingProvider: EdgeEmbeddingProvider {
    func embed(_ text: String) async throws -> EdgeEmbedding {
        let normalized = text.lowercased()

        let travel: Float = (
            normalized.contains("tokyo") ||
            normalized.contains("japan") ||
            normalized.contains("flight") ||
            normalized.contains("newark")
        ) ? 1 : 0

        let food: Float = (
            normalized.contains("dinner") ||
            normalized.contains("restaurant") ||
            normalized.contains("italian")
        ) ? 1 : 0

        return EdgeEmbedding(
            values: [travel, food]
        )
    }
}
