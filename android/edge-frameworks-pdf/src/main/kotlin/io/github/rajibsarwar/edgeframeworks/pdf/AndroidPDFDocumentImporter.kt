package io.github.rajibsarwar.edgeframeworks.pdf

import android.content.ContentResolver
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.rendering.PDFRenderer
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.github.rajibsarwar.edgeframeworks.EdgeDocument
import java.io.Closeable
import java.io.InputStream
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

class AndroidPDFDocumentImporter(
    context: Context
) : Closeable {
    private val recognizer: TextRecognizer =
        TextRecognition.getClient(
            TextRecognizerOptions.DEFAULT_OPTIONS
        )

    init {
        PDFBoxResourceLoader.init(
            context.applicationContext
        )
    }

    suspend fun importDocument(
        contentResolver: ContentResolver,
        uri: Uri,
        sourceName: String,
        documentId: String = UUID.randomUUID().toString()
    ): List<EdgeDocument> {
        return withContext(Dispatchers.IO) {
            val input = contentResolver.openInputStream(uri)
                ?: throw AndroidPDFDocumentImportException.UnreadablePDF

            input.use {
                importDocument(
                    inputStream = it,
                    sourceName = sourceName,
                    documentId = documentId
                )
            }
        }
    }

    suspend fun importDocument(
        inputStream: InputStream,
        sourceName: String,
        documentId: String = UUID.randomUUID().toString()
    ): List<EdgeDocument> {
        return withContext(Dispatchers.IO) {
            PDDocument.load(inputStream).use { pdf ->
                val pageCount = pdf.numberOfPages
                val renderer = PDFRenderer(pdf)
                val documents = mutableListOf<EdgeDocument>()

                for (pageIndex in 0 until pageCount) {
                    val stripper = PDFTextStripper().apply {
                        startPage = pageIndex + 1
                        endPage = pageIndex + 1
                    }

                    val embeddedText = stripper
                        .getText(pdf)
                        .trim()

                    if (embeddedText.isNotEmpty()) {
                        documents += pageDocument(
                            documentId = documentId,
                            sourceName = sourceName,
                            pageNumber = pageIndex + 1,
                            pageCount = pageCount,
                            text = embeddedText,
                            extractionMethod = "embeddedText"
                        )
                        continue
                    }

                    val bitmap = renderer.renderImageWithDPI(
                        pageIndex,
                        OCR_DPI
                    )

                    val recognizedText = try {
                        recognizeText(bitmap)
                    } finally {
                        bitmap.recycle()
                    }

                    if (recognizedText.isNotBlank()) {
                        documents += pageDocument(
                            documentId = documentId,
                            sourceName = sourceName,
                            pageNumber = pageIndex + 1,
                            pageCount = pageCount,
                            text = recognizedText.trim(),
                            extractionMethod = "ocr"
                        )
                    }
                }

                if (documents.isEmpty()) {
                    throw AndroidPDFDocumentImportException.NoExtractableText
                }

                documents
            }
        }
    }

    private suspend fun recognizeText(
        bitmap: Bitmap
    ): String {
        val image = InputImage.fromBitmap(
            bitmap,
            0
        )

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
        private const val OCR_DPI = 200f

        fun pageDocument(
            documentId: String,
            sourceName: String,
            pageNumber: Int,
            pageCount: Int,
            text: String,
            extractionMethod: String = "embeddedText"
        ): EdgeDocument {
            return EdgeDocument(
                id = "$documentId-page-$pageNumber",
                text = text,
                metadata = mapOf(
                    "source" to sourceName,
                    "mediaType" to "application/pdf",
                    "pageNumber" to pageNumber.toString(),
                    "pageCount" to pageCount.toString(),
                    "parentDocumentID" to documentId,
                    "extractionMethod" to extractionMethod,
                    "ocrEngine" to if (extractionMethod == "ocr") {
                        "ML Kit Text Recognition"
                    } else {
                        "none"
                    }
                )
            )
        }
    }
}

sealed class AndroidPDFDocumentImportException(
    message: String
) : IllegalStateException(message) {
    data object UnreadablePDF :
        AndroidPDFDocumentImportException(
            "Unable to read the selected PDF."
        )

    data object NoExtractableText :
        AndroidPDFDocumentImportException(
            "The PDF contains no extractable or OCR-recognizable text."
        )
}
