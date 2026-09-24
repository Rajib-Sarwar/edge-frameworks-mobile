import Foundation
import XCTest
@testable import EdgeFrameworks

final class EdgePersistentRAGTests: XCTestCase {
    func testChunkerSplitsDocumentAndPreservesMetadata() {
        let document = EdgeDocument(
            id: "guide",
            text: """
            First paragraph explains the flight details.

            Second paragraph explains the hotel details.

            Third paragraph explains the train details.
            """,
            metadata: ["source": "guide.txt"]
        )

        let chunks = EdgeTextChunker(
            maxCharacters: 60,
            overlapCharacters: 10
        ).chunk(document)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.first?.documentID, "guide")
        XCTAssertEqual(chunks.first?.metadata["source"], "guide.txt")
        XCTAssertEqual(chunks.first?.metadata["chunkIndex"], "0")
    }

    func testFileVectorStoreSurvivesReopen() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let fileURL = directory.appendingPathComponent("vectors.json")

        let firstStore = try EdgeFileVectorStore(
            fileURL: fileURL
        )

        let chunk = EdgeChunk(
            id: "flight",
            documentID: "travel",
            text: "Tokyo flight leaves Newark at 9:30 AM."
        )

        try await firstStore.upsert(
            chunks: [chunk],
            embeddings: [
                EdgeEmbedding(values: [1, 0])
            ]
        )

        let reopenedStore = try EdgeFileVectorStore(
            fileURL: fileURL
        )

        let results = try await reopenedStore.search(
            query: EdgeEmbedding(values: [1, 0]),
            topK: 1
        )

        XCTAssertEqual(results.first?.chunk, chunk)
        XCTAssertEqual(
            results.first?.score ?? 0,
            1,
            accuracy: 0.0001
        )

        try? FileManager.default.removeItem(at: directory)
    }
}
