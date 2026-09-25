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

    public func index(
        _ document: EdgeDocument,
        in collection: EdgeKnowledgeCollection,
        chunker: EdgeTextChunker = EdgeTextChunker()
    ) async throws {
        let enriched = documentForCollection(
            document,
            collection: collection
        )

        try await index(
            enriched,
            chunker: chunker
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

    public func reindex(
        _ document: EdgeDocument,
        in collection: EdgeKnowledgeCollection,
        chunker: EdgeTextChunker = EdgeTextChunker()
    ) async throws {
        _ = try await remove(
            documentID: document.id,
            from: collection
        )

        try await index(
            document,
            in: collection,
            chunker: chunker
        )
    }

    public func retrieve(
        query: String,
        topK: Int = 3
    ) async throws -> [EdgeSearchResult] {
        try await retrieve(
            query: query,
            filter: nil,
            topK: topK
        )
    }

    public func retrieve(
        query: String,
        in collection: EdgeKnowledgeCollection,
        topK: Int = 3
    ) async throws -> [EdgeSearchResult] {
        try await retrieve(
            query: query,
            filter: EdgeVectorFilter(
                collectionID: collection.id
            ),
            topK: topK
        )
    }

    public func retrieve(
        query: String,
        filter: EdgeVectorFilter?,
        topK: Int = 3
    ) async throws -> [EdgeSearchResult] {
        try Task.checkCancellation()

        let queryEmbedding = try await embeddingProvider.embed(query)

        return try await vectorStore.search(
            query: queryEmbedding,
            topK: topK,
            filter: filter
        )
    }

    public func remove(
        documentID: String,
        from collection: EdgeKnowledgeCollection? = nil
    ) async throws -> Int {
        try await remove(
            documentID: documentID,
            collectionID: collection?.id
        )
    }

    public func remove(
        documentID: String,
        collectionID: String?
    ) async throws -> Int {
        try await vectorStore.remove(
            filter: EdgeVectorFilter(
                documentID: documentID,
                collectionID: collectionID
            )
        )
    }

    public func remove(
        metadata: [String: String],
        from collection: EdgeKnowledgeCollection? = nil
    ) async throws -> Int {
        try await vectorStore.remove(
            filter: EdgeVectorFilter(
                collectionID: collection?.id,
                metadata: metadata
            )
        )
    }

    public func clear(
        _ collection: EdgeKnowledgeCollection
    ) async throws -> Int {
        try await vectorStore.remove(
            filter: EdgeVectorFilter(
                collectionID: collection.id
            )
        )
    }

    private func documentForCollection(
        _ document: EdgeDocument,
        collection: EdgeKnowledgeCollection
    ) -> EdgeDocument {
        var metadata = document.metadata

        for (key, value) in collection.metadata
        where metadata[key] == nil {
            metadata[key] = value
        }

        metadata["collectionID"] = collection.id
        metadata["collectionName"] = collection.name

        return EdgeDocument(
            id: document.id,
            text: document.text,
            metadata: metadata
        )
    }
}
