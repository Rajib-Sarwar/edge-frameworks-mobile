public struct EdgeKnowledgeCollection: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let metadata: [String: String]

    public init(
        id: String,
        name: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.metadata = metadata
    }
}
