public struct EdgeKnowledgeManager: Sendable {
    private let catalog: any EdgeKnowledgeCatalog
    private let indexer: EdgeIncrementalIndexer

    public init(
        catalog: any EdgeKnowledgeCatalog,
        indexer: EdgeIncrementalIndexer
    ) {
        self.catalog = catalog
        self.indexer = indexer
    }

    public func collections()
        async -> [EdgeKnowledgeCollectionSummary]
    {
        let collections = await catalog.collections()
        let sources = await catalog.sources(
            collectionID: nil
        )

        return collections.map { collection in
            let matching = sources.filter {
                $0.collectionID == collection.id
            }

            return EdgeKnowledgeCollectionSummary(
                collection: collection,
                sourceCount: matching.count,
                documentCount: matching.reduce(0) {
                    $0 + $1.documentIDs.count
                },
                lastIndexedAtMilliseconds:
                    matching
                        .map(\.indexedAtMilliseconds)
                        .max()
            )
        }
    }

    public func collection(
        id: String
    ) async -> EdgeKnowledgeCollection? {
        await catalog.collection(id: id)
    }

    public func upsert(
        collection: EdgeKnowledgeCollection
    ) async throws {
        try await catalog.upsert(
            collection: collection
        )
    }

    public func sources(
        in collectionID: String? = nil
    ) async -> [EdgeKnowledgeSource] {
        await catalog.sources(
            collectionID: collectionID
        )
    }

    public func source(
        id: String
    ) async -> EdgeKnowledgeSource? {
        await catalog.source(id: id)
    }

    public func syncSource(
        sourceID: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documents: [EdgeDocument],
        collection: EdgeKnowledgeCollection,
        metadata: [String: String] = [:],
        chunker: EdgeTextChunker = EdgeTextChunker()
    ) async throws -> EdgeSourceSyncResult {
        try await indexer.sync(
            sourceID: sourceID,
            sourceIdentifier: sourceIdentifier,
            contentFingerprint: contentFingerprint,
            documents: documents,
            collection: collection,
            metadata: metadata,
            chunker: chunker
        )
    }

    public func removeSource(
        id: String
    ) async throws -> Int {
        try await indexer.removeSource(id: id)
    }

    public func removeCollection(
        id: String
    ) async throws -> Int {
        guard let collection =
            await catalog.collection(id: id)
        else {
            throw EdgeKnowledgeManagerError
                .collectionNotFound(id)
        }

        return try await indexer.removeCollection(
            collection
        )
    }
}
