package io.github.rajibsarwar.edgeframeworks.documents

import io.github.rajibsarwar.edgeframeworks.EdgeDocument
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.util.UUID
import java.util.zip.ZipInputStream
import javax.xml.parsers.SAXParserFactory
import org.jsoup.Jsoup
import org.xml.sax.Attributes
import org.xml.sax.helpers.DefaultHandler

class AndroidRichDocumentImporter {
    fun importHtml(
        inputStream: InputStream,
        sourceName: String,
        documentId: String = UUID.randomUUID().toString()
    ): EdgeDocument {
        val html = inputStream
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }

        return importHtml(
            html = html,
            sourceName = sourceName,
            documentId = documentId
        )
    }

    fun importHtml(
        html: String,
        sourceName: String,
        documentId: String = UUID.randomUUID().toString()
    ): EdgeDocument {
        val parsed = Jsoup.parse(html)
        parsed.select("script,style,noscript").remove()

        val text = normalizeText(
            parsed.body()?.wholeText()
                ?: parsed.text()
        )

        if (text.isEmpty()) {
            throw AndroidRichDocumentImportException.NoExtractableText
        }

        return EdgeDocument(
            id = documentId,
            text = text,
            metadata = mapOf(
                "source" to sourceName,
                "mediaType" to "text/html",
                "documentFormat" to "html",
                "extractionMethod" to "htmlParser"
            )
        )
    }

    fun importDocx(
        inputStream: InputStream,
        sourceName: String,
        documentId: String = UUID.randomUUID().toString()
    ): EdgeDocument {
        val documentXml = readDocumentXml(inputStream)
            ?: throw AndroidRichDocumentImportException.MissingDocumentXml

        val text = plainTextFromDocxXml(documentXml)

        if (text.isEmpty()) {
            throw AndroidRichDocumentImportException.NoExtractableText
        }

        return EdgeDocument(
            id = documentId,
            text = text,
            metadata = mapOf(
                "source" to sourceName,
                "mediaType" to "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                "documentFormat" to "docx",
                "extractionMethod" to "wordprocessingML"
            )
        )
    }

    internal fun plainTextFromDocxXml(
        data: ByteArray
    ): String {
        val handler = DocxTextHandler()
        val factory = SAXParserFactory.newInstance().apply {
            isNamespaceAware = true
        }

        try {
            factory
                .newSAXParser()
                .parse(
                    ByteArrayInputStream(data),
                    handler
                )
        } catch (error: Exception) {
            throw AndroidRichDocumentImportException.InvalidDocx(
                error
            )
        }

        return normalizeText(handler.text)
    }

    private fun readDocumentXml(
        inputStream: InputStream
    ): ByteArray? {
        return try {
            ZipInputStream(inputStream.buffered()).use { zip ->
                var entry = zip.nextEntry

                while (entry != null) {
                    if (
                        !entry.isDirectory &&
                        entry.name == "word/document.xml"
                    ) {
                        return zip.readBytes()
                    }

                    zip.closeEntry()
                    entry = zip.nextEntry
                }

                null
            }
        } catch (error: Exception) {
            throw AndroidRichDocumentImportException.InvalidDocx(
                error
            )
        }
    }

    private fun normalizeText(
        text: String
    ): String {
        return text
            .replace("\r\n", "\n")
            .replace("\r", "\n")
            .lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .joinToString("\n")
            .trim()
    }
}

sealed class AndroidRichDocumentImportException(
    message: String,
    cause: Throwable? = null
) : IllegalStateException(
    message,
    cause
) {
    data object MissingDocumentXml :
        AndroidRichDocumentImportException(
            "DOCX is missing word/document.xml."
        )

    data object NoExtractableText :
        AndroidRichDocumentImportException(
            "The document contains no extractable text."
        )

    class InvalidDocx(
        cause: Throwable
    ) : AndroidRichDocumentImportException(
        "Unable to parse DOCX.",
        cause
    )
}

private class DocxTextHandler : DefaultHandler() {
    val text: String
        get() = builder.toString()

    private val builder = StringBuilder()
    private var inText = false

    override fun startElement(
        uri: String?,
        localName: String?,
        qName: String?,
        attributes: Attributes?
    ) {
        when (local(localName, qName)) {
            "t" -> inText = true
            "tab" -> builder.append('\t')
            "br" -> builder.append('\n')
        }
    }

    override fun characters(
        ch: CharArray,
        start: Int,
        length: Int
    ) {
        if (inText) {
            builder.append(
                ch,
                start,
                length
            )
        }
    }

    override fun endElement(
        uri: String?,
        localName: String?,
        qName: String?
    ) {
        when (local(localName, qName)) {
            "t" -> inText = false
            "p" -> builder.append('\n')
        }
    }

    private fun local(
        localName: String?,
        qName: String?
    ): String {
        if (!localName.isNullOrEmpty()) {
            return localName
        }

        return qName
            ?.substringAfter(':')
            .orEmpty()
    }
}
