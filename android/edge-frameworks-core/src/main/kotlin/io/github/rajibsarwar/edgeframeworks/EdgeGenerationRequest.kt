package io.github.rajibsarwar.edgeframeworks

data class EdgeGenerationRequest(
    val prompt: String,
    val systemPrompt: String? = null
)
