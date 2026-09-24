import NaturalLanguage

public enum AppleNaturalLanguageEmbeddingError: Error, Equatable, Sendable {
    case unavailable(language: String)
    case noVector(text: String)
}

public actor AppleNaturalLanguageEmbeddingProvider: EdgeEmbeddingProvider {
    private let embedding: NLEmbedding
    public let language: NLLanguage

    public init(language: NLLanguage = .english) throws {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else {
            throw AppleNaturalLanguageEmbeddingError.unavailable(
                language: language.rawValue
            )
        }

        self.embedding = embedding
        self.language = language
    }

    public func embed(_ text: String) async throws -> EdgeEmbedding {
        guard let vector = embedding.vector(for: text) else {
            throw AppleNaturalLanguageEmbeddingError.noVector(text: text)
        }

        return EdgeEmbedding(
            values: vector.map(Float.init)
        )
    }
}
