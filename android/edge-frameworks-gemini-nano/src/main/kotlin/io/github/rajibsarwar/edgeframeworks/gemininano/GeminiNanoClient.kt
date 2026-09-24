package io.github.rajibsarwar.edgeframeworks.gemininano

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

internal interface GeminiNanoClient {
    suspend fun status(): GeminiNanoStatus

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
