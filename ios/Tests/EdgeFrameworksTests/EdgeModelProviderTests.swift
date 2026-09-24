import XCTest
@testable import EdgeFrameworks

final class EdgeModelProviderTests: XCTestCase {
    func testProviderCanGenerateAndStream() async throws {
        let provider = MockProvider()

        let capabilities = await provider.capabilities()
        XCTAssertTrue(capabilities.contains(.textGeneration))
        XCTAssertTrue(capabilities.contains(.streaming))

        let request = EdgeGenerationRequest(prompt: "Hello")
        let response = try await provider.generate(request)
        XCTAssertEqual(response, EdgeGenerationResponse(text: "Hello from mock"))

        var events: [EdgeGenerationEvent] = []
        for try await event in provider.stream(request) {
            events.append(event)
        }

        XCTAssertEqual(
            events,
            [
                .started,
                .token("Hello "),
                .token("from mock"),
                .completed(EdgeGenerationResponse(text: "Hello from mock"))
            ]
        )
    }
}

private struct MockProvider: EdgeModelProvider {
    let id = "mock"

    func capabilities() async -> Set<EdgeCapability> {
        [.textGeneration, .streaming]
    }

    func generate(_ request: EdgeGenerationRequest) async throws -> EdgeGenerationResponse {
        EdgeGenerationResponse(text: "Hello from mock")
    }

    func stream(_ request: EdgeGenerationRequest) -> AsyncThrowingStream<EdgeGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.token("Hello "))
            continuation.yield(.token("from mock"))
            continuation.yield(.completed(EdgeGenerationResponse(text: "Hello from mock")))
            continuation.finish()
        }
    }
}
