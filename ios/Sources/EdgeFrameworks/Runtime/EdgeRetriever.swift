import Foundation

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
        try await retrieveMeasured(
            query: query,
            filter: filter,
            topK: topK
        ).results
    }

    public func retrieveMeasured(
        query: String,
        filter: EdgeVectorFilter? = nil,
        topK: Int = 3
    ) async throws -> EdgeMeasuredRetrieval {
        try Task.checkCancellation()

        let totalStart =
            DispatchTime.now().uptimeNanoseconds
        let embeddingStart = totalStart

        let queryEmbedding =
            try await embeddingProvider.embed(query)

        let embeddingEnd =
            DispatchTime.now().uptimeNanoseconds

        try Task.checkCancellation()

        let results = try await vectorStore.search(
            query: queryEmbedding,
            topK: topK,
            filter: filter
        )

        let searchEnd =
            DispatchTime.now().uptimeNanoseconds

        return EdgeMeasuredRetrieval(
            results: results,
            metrics: EdgeRetrievalMetrics(
                embeddingMilliseconds: Self.milliseconds(
                    from: embeddingStart,
                    to: embeddingEnd
                ),
                searchMilliseconds: Self.milliseconds(
                    from: embeddingEnd,
                    to: searchEnd
                ),
                totalMilliseconds: Self.milliseconds(
                    from: totalStart,
                    to: searchEnd
                ),
                resultCount: results.count,
                topScore: results.first?.score,
                bottomScore: results.last?.score
            )
        )
    }

    public func retrieveHybrid(
        query: String,
        filter: EdgeVectorFilter? = nil,
        topK: Int = 3
    ) async throws -> [EdgeSearchResult] {
        try await retrieveHybridMeasured(
            query: query,
            filter: filter,
            topK: topK
        ).results
    }

    public func retrieveHybridMeasured(
        query: String,
        filter: EdgeVectorFilter? = nil,
        topK: Int = 3
    ) async throws -> EdgeMeasuredRetrieval {
        try Task.checkCancellation()

        guard let lexicalStore =
            vectorStore as? any EdgeLexicalSearchStore
        else {
            throw EdgeRetrievalError
                .hybridSearchUnsupported
        }

        let totalStart =
            DispatchTime.now().uptimeNanoseconds
        let embeddingStart = totalStart

        let queryEmbedding =
            try await embeddingProvider.embed(query)

        let embeddingEnd =
            DispatchTime.now().uptimeNanoseconds

        try Task.checkCancellation()

        let candidateCount =
            max(topK * 3, topK)

        async let vectorResults =
            vectorStore.search(
                query: queryEmbedding,
                topK: candidateCount,
                filter: filter
            )

        async let lexicalResults =
            lexicalStore.lexicalSearch(
                query: query,
                topK: candidateCount,
                filter: filter
            )

        let fused = EdgeHybridRankFusion.fuse(
            vector: try await vectorResults,
            lexical: await lexicalResults,
            query: query,
            topK: topK
        )

        let searchEnd =
            DispatchTime.now().uptimeNanoseconds

        return EdgeMeasuredRetrieval(
            results: fused,
            metrics: EdgeRetrievalMetrics(
                embeddingMilliseconds:
                    Self.milliseconds(
                        from: embeddingStart,
                        to: embeddingEnd
                    ),
                searchMilliseconds:
                    Self.milliseconds(
                        from: embeddingEnd,
                        to: searchEnd
                    ),
                totalMilliseconds:
                    Self.milliseconds(
                        from: totalStart,
                        to: searchEnd
                    ),
                resultCount: fused.count,
                topScore: fused.first?.score,
                bottomScore: fused.last?.score
            )
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

    private static func milliseconds(
        from start: UInt64,
        to end: UInt64
    ) -> Double {
        Double(end - start) / 1_000_000
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
