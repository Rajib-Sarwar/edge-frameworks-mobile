import XCTest
@testable import EdgeFrameworks

final class EdgeHybridRetrievalTests: XCTestCase {
    func testHybridRetrievalRescuesExactIdentifier() async throws {
        let retriever = EdgeRetriever(
            embeddingProvider:
                HybridTestEmbeddingProvider(),
            vectorStore:
                EdgeInMemoryVectorStore()
        )

        try await retriever.index(
            [
                EdgeChunk(
                    id: "semantic",
                    documentID: "semantic",
                    text:
                        "General compressor troubleshooting guidance."
                ),
                EdgeChunk(
                    id: "exact",
                    documentID: "manual",
                    text:
                        "Fault code E31 means condenser airflow is restricted."
                )
            ]
        )

        let vectorOnly = try await retriever.retrieve(
            query: "E31",
            topK: 1
        )

        let hybrid = try await retriever.retrieveHybrid(
            query: "E31",
            topK: 1
        )

        XCTAssertEqual(
            vectorOnly.first?.chunk.id,
            "semantic"
        )
        XCTAssertEqual(
            hybrid.first?.chunk.id,
            "exact"
        )
    }

    func testLexicalSearchHonorsCollectionFilter() async throws {
        let store = EdgeInMemoryVectorStore()

        try await store.upsert(
            chunks: [
                EdgeChunk(
                    id: "a",
                    documentID: "a",
                    text: "Fault E31",
                    metadata: [
                        "collectionID": "one"
                    ]
                ),
                EdgeChunk(
                    id: "b",
                    documentID: "b",
                    text: "Fault E31",
                    metadata: [
                        "collectionID": "two"
                    ]
                )
            ],
            embeddings: [
                EdgeEmbedding(values: [1, 0]),
                EdgeEmbedding(values: [1, 0])
            ]
        )

        let results = await store.lexicalSearch(
            query: "E31",
            topK: 10,
            filter: EdgeVectorFilter(
                collectionID: "two"
            )
        )

        XCTAssertEqual(
            results.map(\.chunk.id),
            ["b"]
        )
    }
}

private struct HybridTestEmbeddingProvider:
    EdgeEmbeddingProvider
{
    func embed(
        _ text: String
    ) async throws -> EdgeEmbedding {
        if text.lowercased().contains(
            "fault code e31"
        ) {
            return EdgeEmbedding(
                values: [0, 1]
            )
        }

        return EdgeEmbedding(
            values: [1, 0]
        )
    }
}
