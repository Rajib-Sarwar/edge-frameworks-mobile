public protocol EdgeVectorStore: Sendable {
    func upsert(
        chunks: [EdgeChunk],
        embeddings: [EdgeEmbedding]
    ) async throws

    func search(
        query: EdgeEmbedding,
        topK: Int,
        filter: EdgeVectorFilter?
    ) async throws -> [EdgeSearchResult]

    func remove(
        filter: EdgeVectorFilter
    ) async throws -> Int

    func removeAll() async
}

public extension EdgeVectorStore {
    func search(
        query: EdgeEmbedding,
        topK: Int
    ) async throws -> [EdgeSearchResult] {
        try await search(
            query: query,
            topK: topK,
            filter: nil
        )
    }
}
