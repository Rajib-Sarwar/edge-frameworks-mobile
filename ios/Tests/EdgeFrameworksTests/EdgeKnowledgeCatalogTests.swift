import Foundation
import XCTest
@testable import EdgeFrameworks

final class EdgeKnowledgeCatalogTests: XCTestCase {
    func testFileCatalogPersistsCollectionsAndSources() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let fileURL = directory.appendingPathComponent("catalog.json")

        let catalog = try EdgeFileKnowledgeCatalog(
            fileURL: fileURL
        )

        let collection = EdgeKnowledgeCollection(
            id: "travel",
            name: "Travel",
            metadata: ["kind": "personal"]
        )

        let source = EdgeKnowledgeSource(
            id: "trip-file",
            collectionID: collection.id,
            sourceIdentifier: "trip.pdf",
            contentFingerprint: "abc123",
            documentIDs: ["trip-page-1"],
            metadata: ["format": "pdf"],
            indexedAtMilliseconds: 42
        )

        try await catalog.upsert(
            collection: collection
        )
        try await catalog.upsert(
            source: source
        )

        let reopened = try EdgeFileKnowledgeCatalog(
            fileURL: fileURL
        )

        let reopenedCollection =
            await reopened.collection(id: "travel")
        let reopenedSource =
            await reopened.source(id: "trip-file")

        XCTAssertEqual(
            reopenedCollection,
            collection
        )
        XCTAssertEqual(
            reopenedSource,
            source
        )

        try? FileManager.default.removeItem(
            at: directory
        )
    }

    func testIncrementalIndexerSkipsUnchangedSourceAndReindexesChangedSource() async throws {
        let embeddingProvider =
            CountingEmbeddingProvider()

        let store = EdgeInMemoryVectorStore()
        let retriever = EdgeRetriever(
            embeddingProvider: embeddingProvider,
            vectorStore: store
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let catalog = try EdgeFileKnowledgeCatalog(
            fileURL: directory
                .appendingPathComponent("catalog.json")
        )

        let indexer = EdgeIncrementalIndexer(
            retriever: retriever,
            catalog: catalog
        )

        let collection = EdgeKnowledgeCollection(
            id: "notes",
            name: "Notes"
        )

        let first = EdgeDocument(
            id: "source-document",
            text: "Tokyo flight leaves at 9:30 AM."
        )

        let firstResult = try await indexer.sync(
            sourceID: "source-1",
            sourceIdentifier: "notes.txt",
            contentFingerprint:
                EdgeContentFingerprint.sha256(first.text),
            documents: [first],
            collection: collection
        )

        guard case .indexed(
            _,
            let firstRemoved,
            let firstIndexed
        ) = firstResult else {
            return XCTFail("Expected initial indexing")
        }

        XCTAssertEqual(firstRemoved, 0)
        XCTAssertEqual(firstIndexed, 1)
        let firstCallCount =
            await embeddingProvider.callCount()
        XCTAssertEqual(
            firstCallCount,
            1
        )

        let unchangedResult = try await indexer.sync(
            sourceID: "source-1",
            sourceIdentifier: "notes.txt",
            contentFingerprint:
                EdgeContentFingerprint.sha256(first.text),
            documents: [
                EdgeDocument(
                    id: "source-document",
                    text: "This should not be embedded."
                )
            ],
            collection: collection
        )

        guard case .unchanged = unchangedResult else {
            return XCTFail("Expected unchanged source")
        }

        let unchangedCallCount =
            await embeddingProvider.callCount()
        XCTAssertEqual(
            unchangedCallCount,
            1
        )

        let changed = EdgeDocument(
            id: "source-document",
            text: "Dinner reservation is at 7 PM."
        )

        let changedResult = try await indexer.sync(
            sourceID: "source-1",
            sourceIdentifier: "notes.txt",
            contentFingerprint:
                EdgeContentFingerprint.sha256(changed.text),
            documents: [changed],
            collection: collection
        )

        guard case .indexed(
            _,
            let removed,
            let indexed
        ) = changedResult else {
            return XCTFail("Expected changed source reindex")
        }

        XCTAssertEqual(removed, 1)
        XCTAssertEqual(indexed, 1)
        let changedCallCount =
            await embeddingProvider.callCount()
        XCTAssertEqual(
            changedCallCount,
            2
        )

        let results = try await retriever.retrieve(
            query: "anything",
            in: collection,
            topK: 5
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(
            results.first?.chunk.text,
            changed.text
        )

        try? FileManager.default.removeItem(
            at: directory
        )
    }
    func testFineGrainedSyncOnlyReembedsChangedPage() async throws {
        let embeddingProvider = CountingEmbeddingProvider()
        let store = EdgeInMemoryVectorStore()
        let retriever = EdgeRetriever(
            embeddingProvider: embeddingProvider,
            vectorStore: store
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let catalog = try EdgeFileKnowledgeCatalog(
            fileURL: directory
                .appendingPathComponent("catalog.json")
        )

        let indexer = EdgeIncrementalIndexer(
            retriever: retriever,
            catalog: catalog
        )

        let collection = EdgeKnowledgeCollection(
            id: "manual",
            name: "Manual"
        )

        let firstDocuments = [
            EdgeDocument(
                id: "old-page-1",
                text: "Page one stays exactly the same.",
                metadata: [
                    "source": "manual.pdf",
                    "pageNumber": "1",
                    "parentDocumentID": "old-parent"
                ]
            ),
            EdgeDocument(
                id: "old-page-2",
                text: "Page two old content.",
                metadata: [
                    "source": "manual.pdf",
                    "pageNumber": "2",
                    "parentDocumentID": "old-parent"
                ]
            )
        ]

        _ = try await indexer.sync(
            sourceID: "manual-source",
            sourceIdentifier: "manual.pdf",
            contentFingerprint: "whole-v1",
            documents: firstDocuments,
            collection: collection
        )

        let initialCalls = await embeddingProvider.callCount()
        XCTAssertEqual(initialCalls, 2)

        let secondDocuments = [
            EdgeDocument(
                id: "new-page-1",
                text: "Page one stays exactly the same.",
                metadata: [
                    "source": "manual.pdf",
                    "pageNumber": "1",
                    "parentDocumentID": "new-parent"
                ]
            ),
            EdgeDocument(
                id: "new-page-2",
                text: "Page two changed content.",
                metadata: [
                    "source": "manual.pdf",
                    "pageNumber": "2",
                    "parentDocumentID": "new-parent"
                ]
            )
        ]

        let result = try await indexer.sync(
            sourceID: "manual-source",
            sourceIdentifier: "manual.pdf",
            contentFingerprint: "whole-v2",
            documents: secondDocuments,
            collection: collection
        )

        guard case .indexed(
            let source,
            let removedChunks,
            let indexedDocuments
        ) = result else {
            return XCTFail("Expected fine-grained indexing")
        }

        XCTAssertEqual(removedChunks, 1)
        XCTAssertEqual(indexedDocuments, 1)
        XCTAssertEqual(
            source.documentStates.first {
                $0.key == "page:1"
            }?.documentID,
            "old-page-1"
        )
        XCTAssertEqual(
            source.documentStates.first {
                $0.key == "page:2"
            }?.documentID,
            "new-page-2"
        )

        let finalCalls = await embeddingProvider.callCount()
        XCTAssertEqual(finalCalls, 3)

        try? FileManager.default.removeItem(
            at: directory
        )
    }

}

private actor CountingEmbeddingProvider:
    EdgeEmbeddingProvider
{
    private var calls = 0

    func embed(
        _ text: String
    ) async throws -> EdgeEmbedding {
        calls += 1
        return EdgeEmbedding(
            values: [1, 1]
        )
    }

    func callCount() -> Int {
        calls
    }
}
