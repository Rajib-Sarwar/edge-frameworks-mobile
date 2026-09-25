import XCTest
@testable import EdgeFrameworks

final class EdgeRAGOrchestrationTests: XCTestCase {
    func testRunRetrievesContextAndGeneratesAnswer() async throws {
        let retriever = EdgeRetriever(
            embeddingProvider: RAGKeywordEmbeddingProvider(),
            vectorStore: EdgeInMemoryVectorStore()
        )

        let collection = EdgeKnowledgeCollection(
            id: "travel",
            name: "Travel"
        )

        try await retriever.index(
            EdgeDocument(
                id: "flight",
                text: "The Tokyo flight leaves Newark at 9:30 AM.",
                metadata: ["source": "trip.txt"]
            ),
            in: collection
        )

        try await retriever.index(
            EdgeDocument(
                id: "dinner",
                text: "Dinner is reserved at 7 PM.",
                metadata: ["source": "food.txt"]
            ),
            in: collection
        )

        let agent = EdgeAgent(
            router: EdgeProviderRouter(
                providers: [RAGEchoProvider()]
            )
        )

        let rag = EdgeRAG(
            retriever: retriever,
            agent: agent
        )

        let result = try await rag.run(
            query: "When does my Tokyo flight leave?",
            in: collection,
            topK: 1
        )

        XCTAssertEqual(
            result.retrievedResults.count,
            1
        )
        XCTAssertEqual(
            result.retrievedResults.first?.chunk.documentID,
            "flight"
        )
        XCTAssertTrue(
            result.context.contains(
                "The Tokyo flight leaves Newark at 9:30 AM."
            )
        )
        XCTAssertTrue(
            result.answer.contains(
                "When does my Tokyo flight leave?"
            )
        )
        XCTAssertTrue(
            result.answer.contains(
                "--- BEGIN LOCAL CONTEXT ---"
            )
        )
    }

    func testMinimumScoreFiltersWeakResults() async throws {
        let retriever = EdgeRetriever(
            embeddingProvider: RAGKeywordEmbeddingProvider(),
            vectorStore: EdgeInMemoryVectorStore()
        )

        try await retriever.index(
            [
                EdgeChunk(
                    id: "flight",
                    documentID: "flight",
                    text: "Tokyo flight from Newark."
                ),
                EdgeChunk(
                    id: "dinner",
                    documentID: "dinner",
                    text: "Italian dinner reservation."
                )
            ]
        )

        let rag = EdgeRAG(
            retriever: retriever,
            agent: EdgeAgent(
                router: EdgeProviderRouter(
                    providers: [RAGEchoProvider()]
                )
            )
        )

        let result = try await rag.run(
            EdgeRAGRequest(
                query: "Tokyo flight",
                topK: 2,
                minimumScore: 0.9
            )
        )

        XCTAssertEqual(
            result.retrievedResults.count,
            1
        )
        XCTAssertEqual(
            result.retrievedResults.first?.chunk.id,
            "flight"
        )
    }
}

private struct RAGEchoProvider: EdgeModelProvider {
    let id = "rag-echo"

    func capabilities() async -> Set<EdgeCapability> {
        [.textGeneration]
    }

    func generate(
        _ request: EdgeGenerationRequest
    ) async throws -> EdgeGenerationResponse {
        EdgeGenerationResponse(
            text: request.prompt
        )
    }

    func stream(
        _ request: EdgeGenerationRequest
    ) -> AsyncThrowingStream<EdgeGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private struct RAGKeywordEmbeddingProvider:
    EdgeEmbeddingProvider
{
    func embed(
        _ text: String
    ) async throws -> EdgeEmbedding {
        let normalized = text.lowercased()

        let travel: Float = (
            normalized.contains("tokyo") ||
            normalized.contains("flight") ||
            normalized.contains("newark")
        ) ? 1 : 0

        let food: Float = (
            normalized.contains("dinner") ||
            normalized.contains("italian")
        ) ? 1 : 0

        return EdgeEmbedding(
            values: [travel, food]
        )
    }
}
