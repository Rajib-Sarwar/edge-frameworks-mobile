import Foundation

public protocol EdgeLexicalSearchStore: Sendable {
    func lexicalSearch(
        query: String,
        topK: Int,
        filter: EdgeVectorFilter?
    ) async -> [EdgeSearchResult]
}

public enum EdgeRetrievalMode: Sendable, Equatable {
    case vector
    case hybrid
}

public enum EdgeRetrievalError: Error, Equatable, Sendable {
    case hybridSearchUnsupported
}

enum EdgeIdentifierMatcher {
    static func identifiers(
        in text: String
    ) -> Set<String> {
        let allowedPunctuation:
            Set<Character> = ["-", "_", "/", "."]

        return Set(
            text.lowercased()
                .split { character in
                    !character.isLetter &&
                    !character.isNumber &&
                    !allowedPunctuation.contains(
                        character
                    )
                }
                .compactMap { raw in
                    let normalized =
                        raw.filter {
                            $0.isLetter ||
                            $0.isNumber
                        }

                    guard
                        normalized.count >= 3,
                        normalized.contains(
                            where: { $0.isLetter }
                        ),
                        normalized.contains(
                            where: { $0.isNumber }
                        )
                    else {
                        return nil
                    }

                    return normalized
                }
        )
    }

    static func matchCount(
        queryIdentifiers: Set<String>,
        in text: String
    ) -> Int {
        guard !queryIdentifiers.isEmpty else {
            return 0
        }

        return queryIdentifiers.intersection(
            identifiers(in: text)
        ).count
    }
}

enum EdgeLexicalSearch {
    static func search(
        query: String,
        chunks: [EdgeChunk],
        topK: Int,
        filter: EdgeVectorFilter?
    ) -> [EdgeSearchResult] {
        guard topK > 0 else { return [] }

        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return [] }

        let queryIdentifiers =
            EdgeIdentifierMatcher.identifiers(
                in: query
            )

        let normalizedQuery =
            query.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).lowercased()

        return chunks.compactMap { chunk in
            if let filter, !filter.matches(chunk) {
                return nil
            }

            let chunkTokens = Set(tokens(chunk.text))
            let matched = queryTokens.filter {
                chunkTokens.contains($0)
            }.count

            let tokenScore =
                Float(matched) /
                Float(queryTokens.count)

            let phraseBonus: Float =
                !normalizedQuery.isEmpty &&
                chunk.text.lowercased()
                    .contains(normalizedQuery)
                    ? 1
                    : 0

            let identifierBonus =
                Float(
                    EdgeIdentifierMatcher.matchCount(
                        queryIdentifiers:
                            queryIdentifiers,
                        in: chunk.text
                    )
                )

            let score =
                tokenScore +
                phraseBonus +
                identifierBonus

            guard score > 0 else { return nil }

            return EdgeSearchResult(
                chunk: chunk,
                score: score
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.chunk.id < rhs.chunk.id
            }
            return lhs.score > rhs.score
        }
        .prefix(topK)
        .map { $0 }
    }

    private static func tokens(
        _ text: String
    ) -> [String] {
        text.lowercased()
            .split { character in
                !character.isLetter &&
                !character.isNumber
            }
            .map(String.init)
    }
}

enum EdgeHybridRankFusion {
    static func fuse(
        vector: [EdgeSearchResult],
        lexical: [EdgeSearchResult],
        query: String,
        topK: Int,
        rrfK: Float = 60
    ) -> [EdgeSearchResult] {
        guard topK > 0 else { return [] }

        var chunks: [String: EdgeChunk] = [:]
        var scores: [String: Float] = [:]

        add(
            vector,
            to: &scores,
            chunks: &chunks,
            rrfK: rrfK
        )
        add(
            lexical,
            to: &scores,
            chunks: &chunks,
            rrfK: rrfK
        )

        let maximumScore =
            2 / (rrfK + 1)

        let queryIdentifiers =
            EdgeIdentifierMatcher.identifiers(
                in: query
            )

        return scores.compactMap {
            id,
            score -> (
                result: EdgeSearchResult,
                identifierMatches: Int
            )? in

            guard let chunk = chunks[id] else {
                return nil
            }

            return (
                EdgeSearchResult(
                    chunk: chunk,
                    score:
                        score / maximumScore
                ),
                EdgeIdentifierMatcher.matchCount(
                    queryIdentifiers:
                        queryIdentifiers,
                    in: chunk.text
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.identifierMatches !=
                rhs.identifierMatches
            {
                return lhs.identifierMatches >
                    rhs.identifierMatches
            }

            if lhs.result.score ==
                rhs.result.score
            {
                return lhs.result.chunk.id <
                    rhs.result.chunk.id
            }

            return lhs.result.score >
                rhs.result.score
        }
        .prefix(topK)
        .map { $0.result }
    }

    private static func add(
        _ results: [EdgeSearchResult],
        to scores: inout [String: Float],
        chunks: inout [String: EdgeChunk],
        rrfK: Float
    ) {
        for (index, result) in results.enumerated() {
            let id = result.chunk.id
            chunks[id] = result.chunk
            scores[id, default: 0] +=
                1 / (rrfK + Float(index + 1))
        }
    }
}
