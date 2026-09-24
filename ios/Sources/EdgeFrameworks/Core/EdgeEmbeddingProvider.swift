public protocol EdgeEmbeddingProvider: Sendable {
    func embed(_ text: String) async throws -> EdgeEmbedding
}
