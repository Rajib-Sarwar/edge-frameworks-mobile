package io.github.rajibsarwar.edgeframeworks.gemininano

import io.github.rajibsarwar.edgeframeworks.EdgeCapability
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationEvent
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationRequest
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationResponse
import io.github.rajibsarwar.edgeframeworks.EdgeModelProvider
import io.github.rajibsarwar.edgeframeworks.EdgeProviderException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

class GeminiNanoProvider : EdgeModelProvider {
    override val id: String = "google.gemini-nano"

    private val client: GeminiNanoClient

    constructor() {
        client = MlKitGeminiNanoClient()
    }

    internal constructor(client: GeminiNanoClient) {
        this.client = client
    }

    override suspend fun capabilities(): Set<EdgeCapability> {
        return try {
            if (client.status() == GeminiNanoStatus.AVAILABLE) {
                setOf(
                    EdgeCapability.TEXT_GENERATION,
                    EdgeCapability.STREAMING
                )
            } else {
                emptySet()
            }
        } catch (_: Exception) {
            emptySet()
        }
    }

    override suspend fun generate(
        request: EdgeGenerationRequest
    ): EdgeGenerationResponse {
        ensureAvailable()

        return try {
            EdgeGenerationResponse(
                text = client.generate(request.toPrompt())
            )
        } catch (error: CancellationException) {
            throw EdgeProviderException.Cancelled
        } catch (error: EdgeProviderException) {
            throw error
        } catch (error: Exception) {
            throw EdgeProviderException.ProviderFailure(
                providerId = id,
                detail = error.message ?: error::class.java.simpleName
            )
        }
    }

    override fun stream(
        request: EdgeGenerationRequest
    ): Flow<EdgeGenerationEvent> = flow {
        ensureAvailable()

        emit(EdgeGenerationEvent.Started)

        try {
            var fullResponse = ""

            client.stream(request.toPrompt()).collect { chunk ->
                if (chunk.isNotEmpty()) {
                    fullResponse += chunk
                    emit(EdgeGenerationEvent.Token(chunk))
                }
            }

            emit(
                EdgeGenerationEvent.Completed(
                    EdgeGenerationResponse(fullResponse)
                )
            )
        } catch (error: CancellationException) {
            throw EdgeProviderException.Cancelled
        } catch (error: EdgeProviderException) {
            throw error
        } catch (error: Exception) {
            throw EdgeProviderException.ProviderFailure(
                providerId = id,
                detail = error.message ?: error::class.java.simpleName
            )
        }
    }

    private suspend fun ensureAvailable() {
        when (client.status()) {
            GeminiNanoStatus.AVAILABLE -> Unit

            GeminiNanoStatus.DOWNLOADABLE,
            GeminiNanoStatus.DOWNLOADING -> {
                throw EdgeProviderException.ModelNotReady(id)
            }

            GeminiNanoStatus.UNAVAILABLE -> {
                throw EdgeProviderException.ProviderUnavailable(id)
            }
        }
    }

    private fun EdgeGenerationRequest.toPrompt(): String {
        val instructions = systemPrompt?.trim().orEmpty()

        return if (instructions.isEmpty()) {
            prompt
        } else {
            "$instructions\n\n$prompt"
        }
    }
}
