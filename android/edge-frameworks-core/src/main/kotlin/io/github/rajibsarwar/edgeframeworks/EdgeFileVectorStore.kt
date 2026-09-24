package io.github.rajibsarwar.edgeframeworks

import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.io.File

class EdgeFileVectorStore(
    private val file: File
) : EdgeVectorStore {
    private data class Record(
        val chunk: EdgeChunk,
        val embedding: EdgeEmbedding
    )

    private val lock = Any()
    private val records = linkedMapOf<String, Record>()

    init {
        load()
    }

    override suspend fun upsert(
        chunks: List<EdgeChunk>,
        embeddings: List<EdgeEmbedding>
    ) {
        if (chunks.size != embeddings.size) {
            throw EdgeVectorException.CountMismatch(
                expected = chunks.size,
                actual = embeddings.size
            )
        }

        synchronized(lock) {
            chunks.zip(embeddings).forEach { (chunk, embedding) ->
                records[chunk.id] = Record(
                    chunk = chunk,
                    embedding = embedding
                )
            }

            persist()
        }
    }

    override suspend fun search(
        query: EdgeEmbedding,
        topK: Int
    ): List<EdgeSearchResult> {
        if (topK <= 0) return emptyList()

        val snapshot = synchronized(lock) {
            records.values.toList()
        }

        return snapshot
            .map { record ->
                EdgeSearchResult(
                    chunk = record.chunk,
                    score = EdgeVectorMath.cosineSimilarity(
                        query,
                        record.embedding
                    )
                )
            }
            .sortedWith(
                compareByDescending<EdgeSearchResult> { it.score }
                    .thenBy { it.chunk.id }
            )
            .take(topK)
    }

    override suspend fun removeAll() {
        synchronized(lock) {
            records.clear()
            persist()
        }
    }

    private fun load() {
        synchronized(lock) {
            if (!file.exists()) return

            try {
                DataInputStream(
                    BufferedInputStream(file.inputStream())
                ).use { input ->
                    val magic = input.readInt()
                    val version = input.readInt()

                    require(magic == MAGIC) {
                        "Invalid Edge vector store file"
                    }

                    require(version == VERSION) {
                        "Unsupported Edge vector store version: $version"
                    }

                    val count = input.readInt()

                    repeat(count) {
                        val id = input.readUTF()
                        val documentId = input.readUTF()
                        val text = input.readUTF()

                        val metadataCount = input.readInt()
                        val metadata = linkedMapOf<String, String>()

                        repeat(metadataCount) {
                            metadata[input.readUTF()] = input.readUTF()
                        }

                        val vectorSize = input.readInt()
                        val values = ArrayList<Float>(vectorSize)

                        repeat(vectorSize) {
                            values += input.readFloat()
                        }

                        records[id] = Record(
                            chunk = EdgeChunk(
                                id = id,
                                documentId = documentId,
                                text = text,
                                metadata = metadata
                            ),
                            embedding = EdgeEmbedding(values)
                        )
                    }
                }
            } catch (_: EOFException) {
                records.clear()
            }
        }
    }

    private fun persist() {
        file.parentFile?.mkdirs()

        val tempFile = File(
            file.parentFile,
            "${file.name}.tmp"
        )

        DataOutputStream(
            BufferedOutputStream(tempFile.outputStream())
        ).use { output ->
            output.writeInt(MAGIC)
            output.writeInt(VERSION)
            output.writeInt(records.size)

            records.values.forEach { record ->
                val chunk = record.chunk
                val embedding = record.embedding

                output.writeUTF(chunk.id)
                output.writeUTF(chunk.documentId)
                output.writeUTF(chunk.text)

                output.writeInt(chunk.metadata.size)
                chunk.metadata.forEach { (key, value) ->
                    output.writeUTF(key)
                    output.writeUTF(value)
                }

                output.writeInt(embedding.values.size)
                embedding.values.forEach(output::writeFloat)
            }
        }

        if (file.exists() && !file.delete()) {
            tempFile.delete()
            throw IllegalStateException(
                "Unable to replace persistent vector store"
            )
        }

        if (!tempFile.renameTo(file)) {
            tempFile.delete()
            throw IllegalStateException(
                "Unable to finalize persistent vector store"
            )
        }
    }

    private companion object {
        const val MAGIC = 0x45444745
        const val VERSION = 1
    }
}
