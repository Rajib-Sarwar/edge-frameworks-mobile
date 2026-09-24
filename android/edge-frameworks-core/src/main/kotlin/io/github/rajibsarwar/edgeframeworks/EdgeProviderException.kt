package io.github.rajibsarwar.edgeframeworks

sealed class EdgeProviderException(
    message: String
) : Exception(message) {
    data class ProviderUnavailable(
        val providerId: String
    ) : EdgeProviderException("Provider unavailable: $providerId")

    data class ModelNotReady(
        val providerId: String
    ) : EdgeProviderException("Model not ready: $providerId")

    data class UnsupportedCapability(
        val capability: EdgeCapability
    ) : EdgeProviderException("Unsupported capability: $capability")

    data object ContextLimitExceeded :
        EdgeProviderException("Context limit exceeded")

    data object Cancelled :
        EdgeProviderException("Generation cancelled")

    data object RateLimited :
        EdgeProviderException("Provider rate limited")

    data class ProviderFailure(
        val providerId: String,
        val detail: String
    ) : EdgeProviderException("$providerId failed: $detail")
}
