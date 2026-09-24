public struct EdgeRetriever: Sendable {
    private let embeddingProvider: any EdgeEmbeddingProvider
    private let vectorStore: any EdgeVectorStore

    public init(
        embeddingProvider: any EdgeEmbeddingProvider,
        vectorStore: any EdgeVectorStore
    ) {
        self.embeddingProvider = embeddingProvider
        self.vectorStore = vectorStore
    }

    public func index(
        _ document: EdgeDocument,
        chunker: EdgeTextChunker = EdgeTextChunker()
    ) async throws {
        try await index(
            chunker.chunk(document)
        )
    }

    public func index(_ chunks: [EdgeChunk]) async throws {
        var embeddings: [EdgeEmbedding] = []
        embeddings.reserveCapacity(chunks.count)

        for chunk in chunks {
            try Task.checkCancellation()
            embeddings.append(
                try await embeddingProvider.embed(chunk.text)
            )
        }

        try await vectorStore.upsert(
            chunks: chunks,
            embeddings: embeddings
        )
    }

    public func retrieve(
        query: String,
        topK: Int = 3
    ) async throws -> [EdgeSearchResult] {
        try Task.checkCancellation()

        let queryEmbedding = try await embeddingProvider.embed(query)

        return try await vectorStore.search(
            query: queryEmbedding,
            topK: topK
        )
    }
}
