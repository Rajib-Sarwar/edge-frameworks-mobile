package io.github.rajibsarwar.edgeframeworks.gemininano

import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

internal enum class GeminiNanoStatus {
    AVAILABLE,
    DOWNLOADABLE,
    DOWNLOADING,
    UNAVAILABLE
}

internal sealed interface GeminiNanoDownloadEvent {
    data class Started(val bytesToDownload: Long) : GeminiNanoDownloadEvent
    data class Progress(val totalBytesDownloaded: Long) : GeminiNanoDownloadEvent
    data object Completed : GeminiNanoDownloadEvent
    data class Failed(val message: String) : GeminiNanoDownloadEvent
}

internal interface GeminiNanoClient {
    suspend fun status(): GeminiNanoStatus

    fun download(): Flow<GeminiNanoDownloadEvent>

    suspend fun generate(prompt: String): String

    fun stream(prompt: String): Flow<String>
}

internal class MlKitGeminiNanoClient : GeminiNanoClient {
    private val model = Generation.getClient()

    override suspend fun status(): GeminiNanoStatus {
        return when (model.checkStatus()) {
            FeatureStatus.AVAILABLE -> GeminiNanoStatus.AVAILABLE
            FeatureStatus.DOWNLOADABLE -> GeminiNanoStatus.DOWNLOADABLE
            FeatureStatus.DOWNLOADING -> GeminiNanoStatus.DOWNLOADING
            else -> GeminiNanoStatus.UNAVAILABLE
        }
    }

    override fun download(): Flow<GeminiNanoDownloadEvent> {
        return model.download().map { status ->
            when (status) {
                is DownloadStatus.DownloadStarted ->
                    GeminiNanoDownloadEvent.Started(
                        bytesToDownload = status.bytesToDownload
                    )

                is DownloadStatus.DownloadProgress ->
                    GeminiNanoDownloadEvent.Progress(
                        totalBytesDownloaded = status.totalBytesDownloaded
                    )

                DownloadStatus.DownloadCompleted ->
                    GeminiNanoDownloadEvent.Completed

                is DownloadStatus.DownloadFailed ->
                    GeminiNanoDownloadEvent.Failed(
                        status.e.message ?: status.e::class.java.simpleName
                    )
            }
        }
    }

    override suspend fun generate(prompt: String): String {
        val response = model.generateContent(prompt)

        return response.candidates.firstOrNull()?.text
            ?: error("Gemini Nano returned no candidates")
    }

    override fun stream(prompt: String): Flow<String> {
        return model.generateContentStream(prompt).map { chunk ->
            chunk.candidates.firstOrNull()?.text.orEmpty()
        }
    }
}
