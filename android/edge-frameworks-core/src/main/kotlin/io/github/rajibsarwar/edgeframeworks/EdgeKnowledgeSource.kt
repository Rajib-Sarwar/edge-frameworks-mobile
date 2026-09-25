package io.github.rajibsarwar.edgeframeworks

data class EdgeSourceDocumentState(
    val key: String,
    val documentId: String,
    val contentFingerprint: String
)

data class EdgeKnowledgeSource(
    val id: String,
    val collectionId: String,
    val sourceIdentifier: String,
    val contentFingerprint: String,
    val documentIds: List<String>,
    val documentStates: List<EdgeSourceDocumentState> =
        emptyList(),
    val metadata: Map<String, String> = emptyMap(),
    val indexedAtMilliseconds: Long =
        System.currentTimeMillis()
)

sealed class EdgeSourceSyncResult {
    data class Unchanged(
        val source: EdgeKnowledgeSource
    ) : EdgeSourceSyncResult()

    data class Indexed(
        val source: EdgeKnowledgeSource,
        val removedChunkCount: Int,
        val indexedDocumentCount: Int
    ) : EdgeSourceSyncResult()
}
