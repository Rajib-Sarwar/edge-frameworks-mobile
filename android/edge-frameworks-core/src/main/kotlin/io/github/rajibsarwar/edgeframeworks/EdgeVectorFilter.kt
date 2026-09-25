package io.github.rajibsarwar.edgeframeworks

data class EdgeVectorFilter(
    val documentId: String? = null,
    val collectionId: String? = null,
    val metadata: Map<String, String> = emptyMap()
) {
    fun matches(chunk: EdgeChunk): Boolean {
        if (
            documentId != null &&
            chunk.documentId != documentId
        ) {
            return false
        }

        if (
            collectionId != null &&
            chunk.metadata["collectionID"] != collectionId
        ) {
            return false
        }

        return metadata.all { (key, value) ->
            chunk.metadata[key] == value
        }
    }
}
