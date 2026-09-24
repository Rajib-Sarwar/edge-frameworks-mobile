package io.github.rajibsarwar.edgeframeworks.mediapipe

import android.content.Context
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import io.github.rajibsarwar.edgeframeworks.EdgeEmbedding
import io.github.rajibsarwar.edgeframeworks.EdgeEmbeddingProvider
import java.io.Closeable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MediaPipeTextEmbeddingProvider(
    context: Context,
    modelAssetPath: String = DEFAULT_MODEL_ASSET_PATH
) : EdgeEmbeddingProvider, Closeable {
    private val lock = Any()

    private val textEmbedder: TextEmbedder = TextEmbedder.createFromOptions(
        context.applicationContext,
        TextEmbedder.TextEmbedderOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath(modelAssetPath)
                    .build()
            )
            .build()
    )

    override suspend fun embed(text: String): EdgeEmbedding =
        withContext(Dispatchers.Default) {
            synchronized(lock) {
                val embedding = textEmbedder
                    .embed(text)
                    .embeddingResult()
                    .embeddings()
                    .firstOrNull()
                    ?: throw MediaPipeTextEmbeddingException.EmptyResult

                val values = embedding.floatEmbedding()

                if (values.isEmpty()) {
                    throw MediaPipeTextEmbeddingException.EmptyResult
                }

                EdgeEmbedding(values.toList())
            }
        }

    override fun close() {
        synchronized(lock) {
            textEmbedder.close()
        }
    }

    companion object {
        const val DEFAULT_MODEL_ASSET_PATH =
            "universal_sentence_encoder.tflite"
    }
}

sealed class MediaPipeTextEmbeddingException(message: String) :
    IllegalStateException(message) {
    data object EmptyResult :
        MediaPipeTextEmbeddingException(
            "MediaPipe Text Embedder returned no floating-point embedding."
        )
}
