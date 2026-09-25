package io.github.rajibsarwar.edgeframeworks

class EdgeInMemoryVectorStore : EdgeVectorStore {
    private data class Entry(
        val chunk: EdgeChunk,
        val embedding: EdgeEmbedding
    )

    private val lock = Any()
    private val entries = linkedMapOf<String, Entry>()

    override suspend fun upsert(
        chunks: List<EdgeChunk>,
        embeddings: List<EdgeEmbedding>
    ) {
        if (chunks.size != embeddings.size) {
            throw EdgeVectorException.CountMismatch(
                expected = chunks.size,
                actual = embeddings.size
            )
        }

        synchronized(lock) {
            chunks.zip(embeddings).forEach { (chunk, embedding) ->
                entries[chunk.id] = Entry(
                    chunk = chunk,
                    embedding = embedding
                )
            }
        }
    }

    override suspend fun search(
        query: EdgeEmbedding,
        topK: Int,
        filter: EdgeVectorFilter?
    ): List<EdgeSearchResult> {
        if (topK <= 0) return emptyList()

        val snapshot = synchronized(lock) {
            entries.values
                .filter { entry ->
                    filter?.matches(entry.chunk) ?: true
                }
                .toList()
        }

        return snapshot
            .map { entry ->
                EdgeSearchResult(
                    chunk = entry.chunk,
                    score = EdgeVectorMath.cosineSimilarity(
                        query,
                        entry.embedding
                    )
                )
            }
            .sortedWith(
                compareByDescending<EdgeSearchResult> { it.score }
                    .thenBy { it.chunk.id }
            )
            .take(topK)
    }

    override suspend fun remove(
        filter: EdgeVectorFilter
    ): Int {
        return synchronized(lock) {
            val matchingIds = entries
                .filterValues { entry ->
                    filter.matches(entry.chunk)
                }
                .keys
                .toList()

            matchingIds.forEach(entries::remove)
            matchingIds.size
        }
    }

    override suspend fun removeAll() {
        synchronized(lock) {
            entries.clear()
        }
    }
}
