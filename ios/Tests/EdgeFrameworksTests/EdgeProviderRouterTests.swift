import XCTest
@testable import EdgeFrameworks

final class EdgeProviderRouterTests: XCTestCase {
    func testSelectsProviderMatchingRequiredCapabilities() async {
        let textOnly = RouterMockProvider(
            id: "text-only",
            capabilities: [.textGeneration]
        )
        let streaming = RouterMockProvider(
            id: "streaming",
            capabilities: [.textGeneration, .streaming]
        )

        let router = EdgeProviderRouter(
            providers: [textOnly, streaming]
        )

        let selected = await router.provider(
            supporting: [.textGeneration, .streaming]
        )

        XCTAssertEqual(selected?.id, "streaming")
    }

    func testAgentFailsWhenNoProviderMatches() async {
        let router = EdgeProviderRouter()
        let agent = EdgeAgent(router: router)

        do {
            _ = try await agent.run(
                EdgeGenerationRequest(prompt: "Hello")
            )
            XCTFail("Expected noCompatibleProvider")
        } catch let error as EdgeAgentError {
            XCTAssertEqual(error, .noCompatibleProvider)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct RouterMockProvider: EdgeModelProvider {
    let id: String
    let supportedCapabilities: Set<EdgeCapability>

    init(
        id: String,
        capabilities: Set<EdgeCapability>
    ) {
        self.id = id
        self.supportedCapabilities = capabilities
    }

    func capabilities() async -> Set<EdgeCapability> {
        supportedCapabilities
    }

    func generate(
        _ request: EdgeGenerationRequest
    ) async throws -> EdgeGenerationResponse {
        EdgeGenerationResponse(text: request.prompt)
    }

    func stream(
        _ request: EdgeGenerationRequest
    ) -> AsyncThrowingStream<EdgeGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.completed(.init(text: request.prompt)))
            continuation.finish()
        }
    }
}
