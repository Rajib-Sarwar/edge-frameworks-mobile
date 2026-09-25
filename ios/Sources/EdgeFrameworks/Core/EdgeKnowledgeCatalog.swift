public protocol EdgeKnowledgeCatalog: Sendable {
    func collections() async -> [EdgeKnowledgeCollection]

    func collection(
        id: String
    ) async -> EdgeKnowledgeCollection?

    func upsert(
        collection: EdgeKnowledgeCollection
    ) async throws

    func removeCollection(
        id: String
    ) async throws

    func sources(
        collectionID: String?
    ) async -> [EdgeKnowledgeSource]

    func source(
        id: String
    ) async -> EdgeKnowledgeSource?

    func upsert(
        source: EdgeKnowledgeSource
    ) async throws

    func removeSource(
        id: String
    ) async throws

    func removeAll() async throws
}
