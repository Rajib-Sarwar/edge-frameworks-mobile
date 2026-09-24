package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.flow.Flow

class EdgeAgent(
    private val router: EdgeProviderRouter
) {
    suspend fun run(
        request: EdgeGenerationRequest,
        requiredCapabilities: Set<EdgeCapability> = setOf(
            EdgeCapability.TEXT_GENERATION
        )
    ): EdgeGenerationResponse {
        val provider = router.provider(requiredCapabilities)
            ?: throw EdgeAgentException.NoCompatibleProvider

        return provider.generate(request)
    }

    suspend fun stream(
        request: EdgeGenerationRequest,
        requiredCapabilities: Set<EdgeCapability> = setOf(
            EdgeCapability.TEXT_GENERATION,
            EdgeCapability.STREAMING
        )
    ): Flow<EdgeGenerationEvent> {
        val provider = router.provider(requiredCapabilities)
            ?: throw EdgeAgentException.NoCompatibleProvider

        return provider.stream(request)
    }
}

sealed class EdgeAgentException(message: String) : Exception(message) {
    data object NoCompatibleProvider :
        EdgeAgentException("No compatible model provider is registered")
}
