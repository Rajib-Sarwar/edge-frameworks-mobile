import Foundation

public struct EdgeSourceDocumentState:
    Codable,
    Equatable,
    Sendable
{
    public let key: String
    public let documentID: String
    public let contentFingerprint: String

    public init(
        key: String,
        documentID: String,
        contentFingerprint: String
    ) {
        self.key = key
        self.documentID = documentID
        self.contentFingerprint = contentFingerprint
    }
}

public struct EdgeKnowledgeSource: Codable, Equatable, Sendable {
    public let id: String
    public let collectionID: String
    public let sourceIdentifier: String
    public let contentFingerprint: String
    public let documentIDs: [String]
    public let documentStates: [EdgeSourceDocumentState]
    public let metadata: [String: String]
    public let indexedAtMilliseconds: Int64

    public init(
        id: String,
        collectionID: String,
        sourceIdentifier: String,
        contentFingerprint: String,
        documentIDs: [String],
        documentStates: [EdgeSourceDocumentState] = [],
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
        self.documentStates = documentStates
        self.metadata = metadata
        self.indexedAtMilliseconds = indexedAtMilliseconds
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case collectionID
        case sourceIdentifier
        case contentFingerprint
        case documentIDs
        case documentStates
        case metadata
        case indexedAtMilliseconds
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        id = try container.decode(
            String.self,
            forKey: .id
        )
        collectionID = try container.decode(
            String.self,
            forKey: .collectionID
        )
        sourceIdentifier = try container.decode(
            String.self,
            forKey: .sourceIdentifier
        )
        contentFingerprint = try container.decode(
            String.self,
            forKey: .contentFingerprint
        )
        documentIDs = try container.decode(
            [String].self,
            forKey: .documentIDs
        )
        documentStates =
            try container.decodeIfPresent(
                [EdgeSourceDocumentState].self,
                forKey: .documentStates
            ) ?? []
        metadata =
            try container.decodeIfPresent(
                [String: String].self,
                forKey: .metadata
            ) ?? [:]
        indexedAtMilliseconds = try container.decode(
            Int64.self,
            forKey: .indexedAtMilliseconds
        )
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
