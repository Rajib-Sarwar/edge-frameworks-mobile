#if canImport(FoundationModels)
import FoundationModels
import Testing
@testable import EdgeFrameworks

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct StructuredOutputFixture {
    let title: String
    let bullets: [String]
}

@available(iOS 26.0, macOS 26.0, *)
private func compileStructuredGenerationCall(
    provider: AppleFoundationModelProvider,
    request: EdgeGenerationRequest
) async throws {
    let _: StructuredOutputFixture = try await provider.generateStructured(
        request,
        as: StructuredOutputFixture.self
    )
}

@Suite("Apple Foundation Models structured output")
struct AppleFoundationModelStructuredOutputTests {
    @Test("Structured generation API accepts Generable output types")
    func structuredGenerationAPIAcceptsGenerableTypes() {
        #expect(true)
    }
}
#endif
