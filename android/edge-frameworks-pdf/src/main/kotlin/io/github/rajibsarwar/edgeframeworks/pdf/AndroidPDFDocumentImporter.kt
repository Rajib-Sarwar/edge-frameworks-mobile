package io.github.rajibsarwar.edgeframeworks.pdf

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.github.rajibsarwar.edgeframeworks.EdgeDocument
import java.io.InputStream
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AndroidPDFDocumentImporter(
    context: Context
) {
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
                val documents = buildList {
                    for (pageIndex in 0 until pageCount) {
                        val stripper = PDFTextStripper().apply {
                            startPage = pageIndex + 1
                            endPage = pageIndex + 1
                        }

                        val text = stripper
                            .getText(pdf)
                            .trim()

                        if (text.isNotEmpty()) {
                            add(
                                pageDocument(
                                    documentId = documentId,
                                    sourceName = sourceName,
                                    pageNumber = pageIndex + 1,
                                    pageCount = pageCount,
                                    text = text
                                )
                            )
                        }
                    }
                }

                if (documents.isEmpty()) {
                    throw AndroidPDFDocumentImportException.NoExtractableText
                }

                documents
            }
        }
    }

    internal companion object {
        fun pageDocument(
            documentId: String,
            sourceName: String,
            pageNumber: Int,
            pageCount: Int,
            text: String
        ): EdgeDocument {
            return EdgeDocument(
                id = "$documentId-page-$pageNumber",
                text = text,
                metadata = mapOf(
                    "source" to sourceName,
                    "mediaType" to "application/pdf",
                    "pageNumber" to pageNumber.toString(),
                    "pageCount" to pageCount.toString(),
                    "parentDocumentID" to documentId
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
            "The PDF contains no extractable text. Scanned PDFs require OCR, which is not part of v0.2."
        )
}
