import Foundation

public actor EdgeFileKnowledgeCatalog: EdgeKnowledgeCatalog {
    private struct State: Codable, Sendable {
        var collections: [String: EdgeKnowledgeCollection]
        var sources: [String: EdgeKnowledgeSource]

        static let empty = State(
            collections: [:],
            sources: [:]
        )
    }

    private let fileURL: URL
    private var state: State

    public init(fileURL: URL) throws {
        self.fileURL = fileURL

        if FileManager.default.fileExists(
            atPath: fileURL.path
        ) {
            let data = try Data(contentsOf: fileURL)
            state = try JSONDecoder().decode(
                State.self,
                from: data
            )
        } else {
            state = .empty
        }
    }

    public func collections() async -> [EdgeKnowledgeCollection] {
        state.collections.values.sorted {
            $0.id < $1.id
        }
    }

    public func collection(
        id: String
    ) async -> EdgeKnowledgeCollection? {
        state.collections[id]
    }

    public func upsert(
        collection: EdgeKnowledgeCollection
    ) async throws {
        state.collections[collection.id] = collection
        try persist()
    }

    public func removeCollection(
        id: String
    ) async throws {
        state.collections.removeValue(forKey: id)
        state.sources = state.sources.filter {
            $0.value.collectionID != id
        }
        try persist()
    }

    public func sources(
        collectionID: String? = nil
    ) async -> [EdgeKnowledgeSource] {
        state.sources.values
            .filter {
                collectionID == nil ||
                $0.collectionID == collectionID
            }
            .sorted {
                $0.id < $1.id
            }
    }

    public func source(
        id: String
    ) async -> EdgeKnowledgeSource? {
        state.sources[id]
    }

    public func upsert(
        source: EdgeKnowledgeSource
    ) async throws {
        state.sources[source.id] = source
        try persist()
    }

    public func removeSource(
        id: String
    ) async throws {
        state.sources.removeValue(forKey: id)
        try persist()
    }

    public func removeAll() async throws {
        state = .empty
        try persist()
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(state)
        try data.write(
            to: fileURL,
            options: [.atomic]
        )
    }
}
