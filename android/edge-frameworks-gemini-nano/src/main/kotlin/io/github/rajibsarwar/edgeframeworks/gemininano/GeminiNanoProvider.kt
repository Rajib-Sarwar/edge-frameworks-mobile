package io.github.rajibsarwar.edgeframeworks.gemininano

import io.github.rajibsarwar.edgeframeworks.EdgeCapability
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationEvent
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationRequest
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationResponse
import io.github.rajibsarwar.edgeframeworks.EdgeModelProvider
import io.github.rajibsarwar.edgeframeworks.EdgeProviderException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map

enum class GeminiNanoAvailability {
    AVAILABLE,
    DOWNLOADABLE,
    DOWNLOADING,
    UNAVAILABLE
}

sealed interface GeminiNanoDownloadState {
    data class Started(val bytesToDownload: Long) : GeminiNanoDownloadState
    data class Progress(val totalBytesDownloaded: Long) : GeminiNanoDownloadState
    data object Completed : GeminiNanoDownloadState
    data class Failed(val message: String) : GeminiNanoDownloadState
}

class GeminiNanoProvider : EdgeModelProvider {
    override val id: String = "google.gemini-nano"

    private val client: GeminiNanoClient

    constructor() {
        client = MlKitGeminiNanoClient()
    }

    internal constructor(client: GeminiNanoClient) {
        this.client = client
    }

    suspend fun availability(): GeminiNanoAvailability {
        return try {
            when (client.status()) {
                GeminiNanoStatus.AVAILABLE -> GeminiNanoAvailability.AVAILABLE
                GeminiNanoStatus.DOWNLOADABLE -> GeminiNanoAvailability.DOWNLOADABLE
                GeminiNanoStatus.DOWNLOADING -> GeminiNanoAvailability.DOWNLOADING
                GeminiNanoStatus.UNAVAILABLE -> GeminiNanoAvailability.UNAVAILABLE
            }
        } catch (_: Exception) {
            GeminiNanoAvailability.UNAVAILABLE
        }
    }

    fun download(): Flow<GeminiNanoDownloadState> {
        return client.download().map { event ->
            when (event) {
                is GeminiNanoDownloadEvent.Started ->
                    GeminiNanoDownloadState.Started(
                        bytesToDownload = event.bytesToDownload
                    )

                is GeminiNanoDownloadEvent.Progress ->
                    GeminiNanoDownloadState.Progress(
                        totalBytesDownloaded = event.totalBytesDownloaded
                    )

                GeminiNanoDownloadEvent.Completed ->
                    GeminiNanoDownloadState.Completed

                is GeminiNanoDownloadEvent.Failed ->
                    GeminiNanoDownloadState.Failed(event.message)
            }
        }
    }

    override suspend fun capabilities(): Set<EdgeCapability> {
        return if (availability() == GeminiNanoAvailability.AVAILABLE) {
            setOf(
                EdgeCapability.TEXT_GENERATION,
                EdgeCapability.STREAMING
            )
        } else {
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
        when (availability()) {
            GeminiNanoAvailability.AVAILABLE -> Unit

            GeminiNanoAvailability.DOWNLOADABLE,
            GeminiNanoAvailability.DOWNLOADING -> {
                throw EdgeProviderException.ModelNotReady(id)
            }

            GeminiNanoAvailability.UNAVAILABLE -> {
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
