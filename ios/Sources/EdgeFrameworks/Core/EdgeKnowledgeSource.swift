import Foundation

public struct EdgeKnowledgeSource: Codable, Equatable, Sendable {
    public let id: String
    public let collectionID: String
    public let sourceIdentifier: String
    public let contentFingerprint: String
    public let documentIDs: [String]
    public let metadata: [String: String]
    public let indexedAtMilliseconds: Int64

    public init(
        id: String,
        collectionID: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documentIDs: [String],
        metadata: [String: String] = [:],
        indexedAtMilliseconds: Int64 = Int64(
            Date().timeIntervalSince1970 * 1_000
        )
    ) {
        self.id = id
        self.collectionID = collectionID
        self.sourceIdentifier = sourceIdentifier
        self.contentFingerprint = contentFingerprint
        self.documentIDs = documentIDs
        self.metadata = metadata
        self.indexedAtMilliseconds = indexedAtMilliseconds
    }
}

public enum EdgeSourceSyncResult: Equatable, Sendable {
    case unchanged(EdgeKnowledgeSource)
    case indexed(
        source: EdgeKnowledgeSource,
        removedChunkCount: Int,
        indexedDocumentCount: Int
    )
}
