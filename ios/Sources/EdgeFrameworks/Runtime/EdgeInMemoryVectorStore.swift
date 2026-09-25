public actor EdgeInMemoryVectorStore: EdgeVectorStore {
    private struct Entry: Sendable {
        let chunk: EdgeChunk
        let embedding: EdgeEmbedding
    }

    private var entries: [String: Entry] = [:]

    public init() {}

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
            entries[chunk.id] = Entry(
                chunk: chunk,
                embedding: embedding
            )
        }
    }

    public func search(
        query: EdgeEmbedding,
        topK: Int,
        filter: EdgeVectorFilter?
    ) async throws -> [EdgeSearchResult] {
        guard topK > 0 else { return [] }

        var results: [EdgeSearchResult] = []
        results.reserveCapacity(entries.count)

        for entry in entries.values {
            if let filter, !filter.matches(entry.chunk) {
                continue
            }
            let score = try EdgeVectorMath.cosineSimilarity(
                query,
                entry.embedding
            )
            results.append(
                EdgeSearchResult(
                    chunk: entry.chunk,
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

    public func remove(
        filter: EdgeVectorFilter
    ) async throws -> Int {
        let matchingIDs = entries
            .filter { filter.matches($0.value.chunk) }
            .map(\.key)

        for id in matchingIDs {
            entries.removeValue(forKey: id)
        }

        return matchingIDs.count
    }

    public func removeAll() async {
        entries.removeAll()
    }
}
