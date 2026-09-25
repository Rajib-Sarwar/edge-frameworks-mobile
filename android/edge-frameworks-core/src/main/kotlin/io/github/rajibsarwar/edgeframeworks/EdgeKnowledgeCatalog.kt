package io.github.rajibsarwar.edgeframeworks

interface EdgeKnowledgeCatalog {
    suspend fun collections(): List<EdgeKnowledgeCollection>

    suspend fun collection(
        id: String
    ): EdgeKnowledgeCollection?

    suspend fun upsert(
        collection: EdgeKnowledgeCollection
    )

    suspend fun removeCollection(
        id: String
    )

    suspend fun sources(
        collectionId: String? = null
    ): List<EdgeKnowledgeSource>

    suspend fun source(
        id: String
    ): EdgeKnowledgeSource?

    suspend fun upsert(
        source: EdgeKnowledgeSource
    )

    suspend fun removeSource(
        id: String
    )

    suspend fun removeAll()
}
