import XCTest
@testable import EdgeFrameworks

final class AppleNaturalLanguageEmbeddingProviderTests: XCTestCase {
    func testEnglishSentenceEmbeddingProducesStableDimension() async throws {
        let provider: AppleNaturalLanguageEmbeddingProvider

        do {
            provider = try AppleNaturalLanguageEmbeddingProvider()
        } catch AppleNaturalLanguageEmbeddingError.unavailable {
            throw XCTSkip("English sentence embeddings are unavailable on this runner.")
        }

        let first = try await provider.embed(
            "A flight leaves Newark for Tokyo."
        )
        let second = try await provider.embed(
            "Dinner is booked at an Italian restaurant."
        )

        XCTAssertFalse(first.values.isEmpty)
        XCTAssertEqual(first.values.count, second.values.count)
    }
}
