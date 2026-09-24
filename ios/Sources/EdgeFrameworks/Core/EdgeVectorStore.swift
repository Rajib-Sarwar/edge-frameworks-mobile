public protocol EdgeVectorStore: Sendable {
    func upsert(
        chunks: [EdgeChunk],
        embeddings: [EdgeEmbedding]
    ) async throws

    func search(
        query: EdgeEmbedding,
        topK: Int
    ) async throws -> [EdgeSearchResult]

    func removeAll() async
}
