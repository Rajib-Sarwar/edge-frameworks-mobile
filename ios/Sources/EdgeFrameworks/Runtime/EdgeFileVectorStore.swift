import Foundation

public actor EdgeFileVectorStore: EdgeVectorStore, EdgeLexicalSearchStore {
    private struct Record: Codable, Sendable {
        let chunk: EdgeChunk
        let embedding: EdgeEmbedding
    }

    private let fileURL: URL
    private var records: [String: Record]

    public init(fileURL: URL) throws {
        self.fileURL = fileURL

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(
                [String: Record].self,
                from: data
            )
            self.records = decoded
        } else {
            self.records = [:]
        }
    }

    public func upsert(
        chunks: [EdgeChunk],
        embeddings: [EdgeEmbedding]
    ) async throws {
        guard chunks.count == embeddings.count else {
            throw EdgeVectorError.countMismatch(
                expected: chunks.count,
                actual: embeddings.count
            )
        }

        for (chunk, embedding) in zip(chunks, embeddings) {
            records[chunk.id] = Record(
                chunk: chunk,
                embedding: embedding
            )
        }

        try persist()
    }

    public func search(
        query: EdgeEmbedding,
        topK: Int,
        filter: EdgeVectorFilter?
    ) async throws -> [EdgeSearchResult] {
        guard topK > 0 else { return [] }

        var results: [EdgeSearchResult] = []
        results.reserveCapacity(records.count)

        for record in records.values {
            if let filter, !filter.matches(record.chunk) {
                continue
            }
            let score = try EdgeVectorMath.cosineSimilarity(
                query,
                record.embedding
            )

            results.append(
                EdgeSearchResult(
                    chunk: record.chunk,
                    score: score
                )
            )
        }

        return Array(
            results
                .sorted { lhs, rhs in
                    if lhs.score == rhs.score {
                        return lhs.chunk.id < rhs.chunk.id
                    }
                    return lhs.score > rhs.score
                }
                .prefix(topK)
        )
    }

    public func lexicalSearch(
        query: String,
        topK: Int,
        filter: EdgeVectorFilter?
    ) async -> [EdgeSearchResult] {
        EdgeLexicalSearch.search(
            query: query,
            chunks: records.values.map(\.chunk),
            topK: topK,
            filter: filter
        )
    }

    public func remove(
        filter: EdgeVectorFilter
    ) async throws -> Int {
        let matchingIDs = records
            .filter { filter.matches($0.value.chunk) }
            .map(\.key)

        for id in matchingIDs {
            records.removeValue(forKey: id)
        }

        if !matchingIDs.isEmpty {
            try persist()
        }

        return matchingIDs.count
    }

    public func removeAll() async {
        records.removeAll()
        try? persist()
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(records)
        try data.write(
            to: fileURL,
            options: [.atomic]
        )
    }
}
