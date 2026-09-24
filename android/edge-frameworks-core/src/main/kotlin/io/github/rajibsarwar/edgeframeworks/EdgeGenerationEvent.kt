package io.github.rajibsarwar.edgeframeworks

sealed interface EdgeGenerationEvent {
    data object Started : EdgeGenerationEvent
    data class Token(val value: String) : EdgeGenerationEvent
    data class Completed(val response: EdgeGenerationResponse) : EdgeGenerationEvent
}
