import Foundation
import XCTest
@testable import EdgeFrameworks

final class EdgeKnowledgeManagerTests: XCTestCase {
    func testCollectionSummariesReflectSourcesAndDocuments() async throws {
        let embeddingProvider = ManagerEmbeddingProvider()
        let retriever = EdgeRetriever(
            embeddingProvider: embeddingProvider,
            vectorStore: EdgeInMemoryVectorStore()
        )
        let catalog = ManagerCatalog()
        let indexer = EdgeIncrementalIndexer(
            retriever: retriever,
            catalog: catalog
        )
        let manager = EdgeKnowledgeManager(
            catalog: catalog,
            indexer: indexer
        )

        let collection = EdgeKnowledgeCollection(
            id: "asset-1",
            name: "Rooftop Unit"
        )

        _ = try await manager.syncSource(
            sourceID: "manual",
            sourceIdentifier: "manual.pdf",
            contentFingerprint: "v1",
            documents: [
                EdgeDocument(
                    id: "page-1",
                    text: "Compressor troubleshooting.",
                    metadata: ["pageNumber": "1"]
                ),
                EdgeDocument(
                    id: "page-2",
                    text: "Control board wiring.",
                    metadata: ["pageNumber": "2"]
                )
            ],
            collection: collection
        )

        let summaries = await manager.collections()

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(
            summaries.first?.collection.id,
            "asset-1"
        )
        XCTAssertEqual(
            summaries.first?.sourceCount,
            1
        )
        XCTAssertEqual(
            summaries.first?.documentCount,
            2
        )
        XCTAssertNotNil(
            summaries.first?
                .lastIndexedAtMilliseconds
        )
    }

    func testRemoveCollectionByIdentifierRemovesCatalogAndVectors() async throws {
        let retriever = EdgeRetriever(
            embeddingProvider: ManagerEmbeddingProvider(),
            vectorStore: EdgeInMemoryVectorStore()
        )
        let catalog = ManagerCatalog()
        let manager = EdgeKnowledgeManager(
            catalog: catalog,
            indexer: EdgeIncrementalIndexer(
                retriever: retriever,
                catalog: catalog
            )
        )

        let collection = EdgeKnowledgeCollection(
            id: "asset-1",
            name: "Rooftop Unit"
        )

        _ = try await manager.syncSource(
            sourceID: "manual",
            sourceIdentifier: "manual.pdf",
            contentFingerprint: "v1",
            documents: [
                EdgeDocument(
                    id: "page-1",
                    text: "Compressor troubleshooting."
                )
            ],
            collection: collection
        )

        let removed = try await manager.removeCollection(
            id: collection.id
        )

        XCTAssertEqual(removed, 1)
        XCTAssertNil(
            await manager.collection(
                id: collection.id
            )
        )
        XCTAssertTrue(
            await manager.sources().isEmpty
        )
    }
}

private struct ManagerEmbeddingProvider:
    EdgeEmbeddingProvider
{
    func embed(
        _ text: String
    ) async throws -> EdgeEmbedding {
        EdgeEmbedding(values: [1, 1])
    }
}

private actor ManagerCatalog: EdgeKnowledgeCatalog {
    private var collectionsByID:
        [String: EdgeKnowledgeCollection] = [:]
    private var sourcesByID:
        [String: EdgeKnowledgeSource] = [:]

    func collections() async -> [EdgeKnowledgeCollection] {
        collectionsByID.values.sorted {
            $0.id < $1.id
        }
    }

    func collection(
        id: String
    ) async -> EdgeKnowledgeCollection? {
        collectionsByID[id]
    }

    func upsert(
        collection: EdgeKnowledgeCollection
    ) async throws {
        collectionsByID[collection.id] =
            collection
    }

    func removeCollection(
        id: String
    ) async throws {
        collectionsByID.removeValue(
            forKey: id
        )
        sourcesByID = sourcesByID.filter {
            $0.value.collectionID != id
        }
    }

    func sources(
        collectionID: String?
    ) async -> [EdgeKnowledgeSource] {
        sourcesByID.values
            .filter {
                collectionID == nil ||
                $0.collectionID ==
                    collectionID
            }
            .sorted {
                $0.id < $1.id
            }
    }

    func source(
        id: String
    ) async -> EdgeKnowledgeSource? {
        sourcesByID[id]
    }

    func upsert(
        source: EdgeKnowledgeSource
    ) async throws {
        sourcesByID[source.id] =
            source
    }

    func removeSource(
        id: String
    ) async throws {
        sourcesByID.removeValue(
            forKey: id
        )
    }

    func removeAll() async throws {
        collectionsByID.removeAll()
        sourcesByID.removeAll()
    }
}
