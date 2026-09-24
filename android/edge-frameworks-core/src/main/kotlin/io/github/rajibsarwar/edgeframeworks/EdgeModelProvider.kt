package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.flow.Flow

interface EdgeModelProvider {
    val id: String

    suspend fun capabilities(): Set<EdgeCapability>

    suspend fun generate(
        request: EdgeGenerationRequest
    ): EdgeGenerationResponse

    fun stream(
        request: EdgeGenerationRequest
    ): Flow<EdgeGenerationEvent>
}
