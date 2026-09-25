package io.github.rajibsarwar.edgeframeworks.images

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.github.rajibsarwar.edgeframeworks.EdgeDocument
import java.io.Closeable
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

class AndroidImageDocumentImporter(
    private val context: Context
) : Closeable {
    private val recognizer: TextRecognizer =
        TextRecognition.getClient(
            TextRecognizerOptions.DEFAULT_OPTIONS
        )

    suspend fun importDocument(
        uri: Uri,
        sourceName: String,
        mediaType: String = "image/*",
        documentId: String = UUID.randomUUID().toString()
    ): EdgeDocument {
        val image = try {
            InputImage.fromFilePath(
                context,
                uri
            )
        } catch (error: Exception) {
            throw AndroidImageDocumentImportException.InvalidImage(
                error
            )
        }

        val text = recognizeText(image)
            .trim()

        if (text.isEmpty()) {
            throw AndroidImageDocumentImportException.NoRecognizedText
        }

        return imageDocument(
            documentId = documentId,
            sourceName = sourceName,
            mediaType = mediaType,
            text = text
        )
    }

    private suspend fun recognizeText(
        image: InputImage
    ): String {
        return suspendCancellableCoroutine { continuation ->
            recognizer
                .process(image)
                .addOnSuccessListener { result ->
                    if (continuation.isActive) {
                        continuation.resume(result.text)
                    }
                }
                .addOnFailureListener { error ->
                    if (continuation.isActive) {
                        continuation.resumeWithException(error)
                    }
                }
        }
    }

    override fun close() {
        recognizer.close()
    }

    internal companion object {
        fun imageDocument(
            documentId: String,
            sourceName: String,
            mediaType: String,
            text: String
        ): EdgeDocument {
            return EdgeDocument(
                id = documentId,
                text = text,
                metadata = mapOf(
                    "source" to sourceName,
                    "mediaType" to mediaType,
                    "documentFormat" to "image",
                    "extractionMethod" to "ocr",
                    "ocrEngine" to "ML Kit Text Recognition"
                )
            )
        }
    }
}

sealed class AndroidImageDocumentImportException(
    message: String,
    cause: Throwable? = null
) : IllegalStateException(
    message,
    cause
) {
    class InvalidImage(
        cause: Throwable
    ) : AndroidImageDocumentImportException(
        "Unable to decode selected image.",
        cause
    )

    data object NoRecognizedText :
        AndroidImageDocumentImportException(
            "The image contains no OCR-recognizable text."
        )
}
