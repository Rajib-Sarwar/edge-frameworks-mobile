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

    func testHybridRetrievalPrioritizesIdentifierInsideNaturalLanguageQuery() async throws {
        let retriever = EdgeRetriever(
            embeddingProvider:
                NaturalLanguageIdentifierEmbeddingProvider(),
            vectorStore:
                EdgeInMemoryVectorStore()
        )

        try await retriever.index(
            [
                EdgeChunk(
                    id: "generic-indoor-outdoor",
                    documentID: "manual-page-9",
                    text:
                        "Indoor and outdoor unit installation model selection guidance."
                ),
                EdgeChunk(
                    id: "generic-outdoor",
                    documentID: "manual-page-19",
                    text:
                        "Outdoor unit model wiring installation."
                ),
                EdgeChunk(
                    id: "generic-indoor",
                    documentID: "manual-page-12",
                    text:
                        "Indoor unit installation safety."
                ),
                EdgeChunk(
                    id: "exact-model",
                    documentID: "manual-page-1",
                    text:
                        "INDOOR UNITS Type Model DCP09NWB11S DHP09NWB11S DCP12NWB11S."
                )
            ]
        )

        let query =
            "Is model DCP09NWB11S an indoor or outdoor unit?"

        let vectorOnly = try await retriever.retrieve(
            query: query,
            topK: 1
        )

        let hybrid = try await retriever.retrieveHybrid(
            query: query,
            topK: 1
        )

        XCTAssertNotEqual(
            vectorOnly.first?.chunk.id,
            "exact-model"
        )
        XCTAssertEqual(
            hybrid.first?.chunk.id,
            "exact-model"
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


private struct NaturalLanguageIdentifierEmbeddingProvider:
    EdgeEmbeddingProvider
{
    func embed(
        _ text: String
    ) async throws -> EdgeEmbedding {
        let normalized = text.lowercased()

        if normalized.hasPrefix(
            "is model dcp09nwb11s"
        ) {
            return EdgeEmbedding(
                values: [1, 0]
            )
        }

        if normalized.contains(
            "dcp09nwb11s"
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
