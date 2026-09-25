package io.github.rajibsarwar.edgeframeworks

data class EdgeKnowledgeCollectionSummary(
    val collection: EdgeKnowledgeCollection,
    val sourceCount: Int,
    val documentCount: Int,
    val lastIndexedAtMilliseconds: Long?
)

sealed class EdgeKnowledgeManagerException(
    message: String
) : Exception(message) {
    data class CollectionNotFound(
        val collectionId: String
    ) : EdgeKnowledgeManagerException(
        "Knowledge collection not found: $collectionId"
    )
}
