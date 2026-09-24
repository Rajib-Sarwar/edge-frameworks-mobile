import XCTest
@testable import EdgeFrameworks

final class EdgeBenchmarkRunnerTests: XCTestCase {
    func testRunnerSummarizesProviderIterations() async throws {
        let provider = BenchmarkTestProvider()
        let runner = EdgeBenchmarkRunner()

        let summary = try await runner.run(
            provider: provider,
            request: EdgeGenerationRequest(prompt: "hello"),
            iterations: 3
        )

        XCTAssertEqual(summary.providerID, "benchmark.test")
        XCTAssertEqual(summary.iterations, 3)
        XCTAssertGreaterThanOrEqual(
            summary.averageLatencyMilliseconds,
            0
        )
        XCTAssertGreaterThanOrEqual(
            summary.p50LatencyMilliseconds,
            0
        )
        XCTAssertGreaterThanOrEqual(
            summary.p95LatencyMilliseconds,
            0
        )
    }
}

private struct BenchmarkTestProvider: EdgeModelProvider {
    let id = "benchmark.test"

    func capabilities() async -> Set<EdgeCapability> {
        [.textGeneration]
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
            continuation.finish()
        }
    }
}
