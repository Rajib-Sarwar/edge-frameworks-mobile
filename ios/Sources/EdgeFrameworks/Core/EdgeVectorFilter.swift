public struct EdgeVectorFilter: Equatable, Sendable {
    public let documentID: String?
    public let collectionID: String?
    public let metadata: [String: String]

    public init(
        documentID: String? = nil,
        collectionID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.documentID = documentID
        self.collectionID = collectionID
        self.metadata = metadata
    }

    public func matches(_ chunk: EdgeChunk) -> Bool {
        if let documentID, chunk.documentID != documentID {
            return false
        }

        if let collectionID,
           chunk.metadata["collectionID"] != collectionID {
            return false
        }

        for (key, value) in metadata
        where chunk.metadata[key] != value {
            return false
        }

        return true
    }
}
