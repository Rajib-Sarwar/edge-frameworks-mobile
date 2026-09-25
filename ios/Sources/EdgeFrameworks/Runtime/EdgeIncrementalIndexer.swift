import Foundation

public struct EdgeIncrementalIndexer: Sendable {
    private let retriever: EdgeRetriever
    private let catalog: any EdgeKnowledgeCatalog

    public init(
        retriever: EdgeRetriever,
        catalog: any EdgeKnowledgeCatalog
    ) {
        self.retriever = retriever
        self.catalog = catalog
    }

    public func sync(
        sourceID: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documents: [EdgeDocument],
        collection: EdgeKnowledgeCollection,
        metadata: [String: String] = [:],
        chunker: EdgeTextChunker = EdgeTextChunker()
    ) async throws -> EdgeSourceSyncResult {
        try Task.checkCancellation()

        if let existing = await catalog.source(id: sourceID),
           existing.collectionID == collection.id,
           existing.contentFingerprint == contentFingerprint {
            return .unchanged(existing)
        }

        let previous = await catalog.source(id: sourceID)
        var removedChunkCount = 0

        if let previous {
            for documentID in previous.documentIDs {
                try Task.checkCancellation()
                removedChunkCount += try await retriever.remove(
                    documentID: documentID,
                    collectionID: previous.collectionID
                )
            }
        }

        for document in documents {
            try Task.checkCancellation()
            try await retriever.index(
                document,
                in: collection,
                chunker: chunker
            )
        }

        let source = EdgeKnowledgeSource(
            id: sourceID,
            collectionID: collection.id,
            sourceIdentifier: sourceIdentifier,
            contentFingerprint: contentFingerprint,
            documentIDs: documents.map(\.id),
            metadata: metadata
        )

        try await catalog.upsert(
            collection: collection
        )
        try await catalog.upsert(
            source: source
        )

        return .indexed(
            source: source,
            removedChunkCount: removedChunkCount,
            indexedDocumentCount: documents.count
        )
    }

    public func removeSource(
        id: String
    ) async throws -> Int {
        guard let source = await catalog.source(id: id) else {
            return 0
        }

        var removed = 0

        for documentID in source.documentIDs {
            try Task.checkCancellation()
            removed += try await retriever.remove(
                documentID: documentID,
                collectionID: source.collectionID
            )
        }

        try await catalog.removeSource(id: id)
        return removed
    }

    public func removeCollection(
        _ collection: EdgeKnowledgeCollection
    ) async throws -> Int {
        let removed = try await retriever.clear(collection)
        try await catalog.removeCollection(id: collection.id)
        return removed
    }
}
