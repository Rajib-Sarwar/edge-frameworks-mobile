package io.github.rajibsarwar.edgeframeworks

class EdgeTextChunker(
    val maxCharacters: Int = 800,
    val overlapCharacters: Int = 120
) {
    init {
        require(maxCharacters > 0)
        require(overlapCharacters >= 0)
        require(overlapCharacters < maxCharacters)
    }

    fun chunk(document: EdgeDocument): List<EdgeChunk> {
        val normalized = document.text
            .replace("\r\n", "\n")
            .trim()

        if (normalized.isEmpty()) return emptyList()

        val chunks = mutableListOf<EdgeChunk>()
        var start = 0
        var chunkIndex = 0

        while (start < normalized.length) {
            val tentativeEnd = (start + maxCharacters)
                .coerceAtMost(normalized.length)

            var end = tentativeEnd

            if (end < normalized.length) {
                val window = normalized.substring(start, end)

                val paragraphBreak = window.lastIndexOf("\n\n")
                val sentenceBreak = window.lastIndexOf(". ")
                val whitespace = window.indexOfLast { it.isWhitespace() }

                end = when {
                    paragraphBreak >= 0 -> start + paragraphBreak
                    sentenceBreak >= 0 -> start + sentenceBreak + 2
                    whitespace >= 0 -> start + whitespace
                    else -> tentativeEnd
                }
            }

            if (end <= start) {
                end = tentativeEnd
            }

            val text = normalized
                .substring(start, end)
                .trim()

            if (text.isNotEmpty()) {
                val metadata = document.metadata.toMutableMap()
                metadata["chunkIndex"] = chunkIndex.toString()

                chunks += EdgeChunk(
                    id = "${document.id}-chunk-$chunkIndex",
                    documentId = document.id,
                    text = text,
                    metadata = metadata
                )

                chunkIndex += 1
            }

            if (end >= normalized.length) break

            val overlapStart = (end - overlapCharacters)
                .coerceAtLeast(start)

            start = if (overlapStart == start) {
                end
            } else {
                overlapStart
            }
        }

        return chunks
    }
}
