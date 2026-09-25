package io.github.rajibsarwar.edgeframeworks

data class EdgeKnowledgeCollection(
    val id: String,
    val name: String,
    val metadata: Map<String, String> = emptyMap()
)
