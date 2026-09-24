public struct EdgeTextChunker: Sendable {
    public let maxCharacters: Int
    public let overlapCharacters: Int

    public init(
        maxCharacters: Int = 800,
        overlapCharacters: Int = 120
    ) {
        precondition(maxCharacters > 0)
        precondition(overlapCharacters >= 0)
        precondition(overlapCharacters < maxCharacters)

        self.maxCharacters = maxCharacters
        self.overlapCharacters = overlapCharacters
    }

    public func chunk(_ document: EdgeDocument) -> [EdgeChunk] {
        let normalized = document.text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }

        var chunks: [EdgeChunk] = []
        var start = normalized.startIndex
        var index = 0

        while start < normalized.endIndex {
            let tentativeEnd = normalized.index(
                start,
                offsetBy: maxCharacters,
                limitedBy: normalized.endIndex
            ) ?? normalized.endIndex

            var end = tentativeEnd

            if end < normalized.endIndex {
                let window = normalized[start..<end]

                if let paragraphBreak = window.range(
                    of: "\n\n",
                    options: .backwards
                ) {
                    end = paragraphBreak.lowerBound
                } else if let sentenceBreak = window.range(
                    of: ". ",
                    options: .backwards
                ) {
                    end = sentenceBreak.upperBound
                } else if let whitespace = window.lastIndex(
                    where: { $0.isWhitespace }
                ) {
                    end = whitespace
                }
            }

            if end <= start {
                end = tentativeEnd
            }

            let text = String(normalized[start..<end])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                var metadata = document.metadata
                metadata["chunkIndex"] = String(index)

                chunks.append(
                    EdgeChunk(
                        id: "\(document.id)-chunk-\(index)",
                        documentID: document.id,
                        text: text,
                        metadata: metadata
                    )
                )

                index += 1
            }

            if end >= normalized.endIndex {
                break
            }

            let overlapStart = normalized.index(
                end,
                offsetBy: -overlapCharacters,
                limitedBy: start
            ) ?? start

            start = overlapStart == start
                ? end
                : overlapStart
        }

        return chunks
    }
}
