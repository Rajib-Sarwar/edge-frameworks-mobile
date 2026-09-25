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

        let existing = await catalog.source(id: sourceID)

        if let existing,
           existing.collectionID == collection.id,
           existing.contentFingerprint == contentFingerprint {
            return .unchanged(existing)
        }

        if let existing,
           existing.collectionID == collection.id,
           !existing.documentStates.isEmpty {
            return try await syncFineGrained(
                existing: existing,
                sourceID: sourceID,
                sourceIdentifier: sourceIdentifier,
                contentFingerprint: contentFingerprint,
                documents: documents,
                collection: collection,
                metadata: metadata,
                chunker: chunker
            )
        }

        return try await replaceWholeSource(
            existing: existing,
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

    private func syncFineGrained(
        existing: EdgeKnowledgeSource,
        sourceID: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documents: [EdgeDocument],
        collection: EdgeKnowledgeCollection,
        metadata: [String: String],
        chunker: EdgeTextChunker
    ) async throws -> EdgeSourceSyncResult {
        let previousByKey = Dictionary(
            uniqueKeysWithValues:
                existing.documentStates.map {
                    ($0.key, $0)
                }
        )

        let incoming = documents.enumerated().map {
            index,
            document in

            (
                document: document,
                key: documentKey(
                    document,
                    index: index
                ),
                fingerprint:
                    documentFingerprint(document)
            )
        }

        let incomingKeys = Set(
            incoming.map(\.key)
        )

        var removedChunkCount = 0
        var indexedDocumentCount = 0
        var nextStates: [EdgeSourceDocumentState] = []
        nextStates.reserveCapacity(incoming.count)

        for oldState in existing.documentStates
        where !incomingKeys.contains(oldState.key) {
            try Task.checkCancellation()

            removedChunkCount += try await retriever.remove(
                documentID: oldState.documentID,
                collectionID: existing.collectionID
            )
        }

        for item in incoming {
            try Task.checkCancellation()

            if let previous = previousByKey[item.key],
               previous.contentFingerprint == item.fingerprint {
                nextStates.append(previous)
                continue
            }

            if let previous = previousByKey[item.key] {
                removedChunkCount += try await retriever.remove(
                    documentID: previous.documentID,
                    collectionID: existing.collectionID
                )
            }

            try await retriever.index(
                item.document,
                in: collection,
                chunker: chunker
            )

            indexedDocumentCount += 1
            nextStates.append(
                EdgeSourceDocumentState(
                    key: item.key,
                    documentID: item.document.id,
                    contentFingerprint: item.fingerprint
                )
            )
        }

        let source = EdgeKnowledgeSource(
            id: sourceID,
            collectionID: collection.id,
            sourceIdentifier: sourceIdentifier,
            contentFingerprint: contentFingerprint,
            documentIDs: nextStates.map(\.documentID),
            documentStates: nextStates,
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
            indexedDocumentCount: indexedDocumentCount
        )
    }

    private func replaceWholeSource(
        existing: EdgeKnowledgeSource?,
        sourceID: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documents: [EdgeDocument],
        collection: EdgeKnowledgeCollection,
        metadata: [String: String],
        chunker: EdgeTextChunker
    ) async throws -> EdgeSourceSyncResult {
        var removedChunkCount = 0

        if let existing {
            for documentID in existing.documentIDs {
                try Task.checkCancellation()

                removedChunkCount += try await retriever.remove(
                    documentID: documentID,
                    collectionID: existing.collectionID
                )
            }
        }

        var states: [EdgeSourceDocumentState] = []
        states.reserveCapacity(documents.count)

        for (index, document) in documents.enumerated() {
            try Task.checkCancellation()

            try await retriever.index(
                document,
                in: collection,
                chunker: chunker
            )

            states.append(
                EdgeSourceDocumentState(
                    key: documentKey(
                        document,
                        index: index
                    ),
                    documentID: document.id,
                    contentFingerprint:
                        documentFingerprint(document)
                )
            )
        }

        let source = EdgeKnowledgeSource(
            id: sourceID,
            collectionID: collection.id,
            sourceIdentifier: sourceIdentifier,
            contentFingerprint: contentFingerprint,
            documentIDs: states.map(\.documentID),
            documentStates: states,
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

    private func documentKey(
        _ document: EdgeDocument,
        index: Int
    ) -> String {
        if let pageNumber =
            document.metadata["pageNumber"] {
            return "page:\(pageNumber)"
        }

        if let sectionID =
            document.metadata["sourceSectionID"] {
            return "section:\(sectionID)"
        }

        return "index:\(index)"
    }

    private func documentFingerprint(
        _ document: EdgeDocument
    ) -> String {
        let metadata = document.metadata
            .filter {
                $0.key != "parentDocumentID"
            }
            .sorted {
                $0.key < $1.key
            }
            .map {
                "\($0.key)=\($0.value)"
            }
            .joined(separator: "\n")

        return EdgeContentFingerprint.sha256(
            """
            \(document.text)
            ---
            \(metadata)
            """
        )
    }
}
