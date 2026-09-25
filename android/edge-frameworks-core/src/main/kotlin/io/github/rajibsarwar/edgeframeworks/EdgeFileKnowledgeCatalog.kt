package io.github.rajibsarwar.edgeframeworks

import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.io.File

class EdgeFileKnowledgeCatalog(
    private val file: File
) : EdgeKnowledgeCatalog {
    private val lock = Any()
    private val collections =
        linkedMapOf<String, EdgeKnowledgeCollection>()
    private val sources =
        linkedMapOf<String, EdgeKnowledgeSource>()

    init {
        load()
    }

    override suspend fun collections(): List<EdgeKnowledgeCollection> {
        return synchronized(lock) {
            collections.values
                .sortedBy { it.id }
        }
    }

    override suspend fun collection(
        id: String
    ): EdgeKnowledgeCollection? {
        return synchronized(lock) {
            collections[id]
        }
    }

    override suspend fun upsert(
        collection: EdgeKnowledgeCollection
    ) {
        synchronized(lock) {
            collections[collection.id] = collection
            persist()
        }
    }

    override suspend fun removeCollection(
        id: String
    ) {
        synchronized(lock) {
            collections.remove(id)
            sources.entries.removeAll {
                it.value.collectionId == id
            }
            persist()
        }
    }

    override suspend fun sources(
        collectionId: String?
    ): List<EdgeKnowledgeSource> {
        return synchronized(lock) {
            sources.values
                .filter {
                    collectionId == null ||
                    it.collectionId == collectionId
                }
                .sortedBy { it.id }
        }
    }

    override suspend fun source(
        id: String
    ): EdgeKnowledgeSource? {
        return synchronized(lock) {
            sources[id]
        }
    }

    override suspend fun upsert(
        source: EdgeKnowledgeSource
    ) {
        synchronized(lock) {
            sources[source.id] = source
            persist()
        }
    }

    override suspend fun removeSource(
        id: String
    ) {
        synchronized(lock) {
            sources.remove(id)
            persist()
        }
    }

    override suspend fun removeAll() {
        synchronized(lock) {
            collections.clear()
            sources.clear()
            persist()
        }
    }

    private fun load() {
        synchronized(lock) {
            if (!file.exists()) return

            try {
                DataInputStream(
                    BufferedInputStream(
                        file.inputStream()
                    )
                ).use { input ->
                    val magic = input.readInt()
                    val version = input.readInt()

                    require(magic == MAGIC) {
                        "Invalid Edge knowledge catalog file"
                    }

                    require(version == VERSION) {
                        "Unsupported Edge knowledge catalog version: $version"
                    }

                    repeat(input.readInt()) {
                        val id = input.readUTF()
                        collections[id] =
                            EdgeKnowledgeCollection(
                                id = id,
                                name = input.readUTF(),
                                metadata = input.readStringMap()
                            )
                    }

                    repeat(input.readInt()) {
                        val id = input.readUTF()
                        val collectionId = input.readUTF()
                        val sourceIdentifier = input.readUTF()
                        val contentFingerprint = input.readUTF()

                        val documentIds =
                            buildList {
                                repeat(input.readInt()) {
                                    add(input.readUTF())
                                }
                            }

                        val metadata =
                            input.readStringMap()

                        val indexedAtMilliseconds =
                            input.readLong()

                        sources[id] = EdgeKnowledgeSource(
                            id = id,
                            collectionId = collectionId,
                            sourceIdentifier = sourceIdentifier,
                            contentFingerprint = contentFingerprint,
                            documentIds = documentIds,
                            metadata = metadata,
                            indexedAtMilliseconds = indexedAtMilliseconds
                        )
                    }
                }
            } catch (_: EOFException) {
                collections.clear()
                sources.clear()
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
            BufferedOutputStream(
                tempFile.outputStream()
            )
        ).use { output ->
            output.writeInt(MAGIC)
            output.writeInt(VERSION)

            output.writeInt(collections.size)
            collections.values.forEach { collection ->
                output.writeUTF(collection.id)
                output.writeUTF(collection.name)
                output.writeStringMap(
                    collection.metadata
                )
            }

            output.writeInt(sources.size)
            sources.values.forEach { source ->
                output.writeUTF(source.id)
                output.writeUTF(source.collectionId)
                output.writeUTF(source.sourceIdentifier)
                output.writeUTF(source.contentFingerprint)

                output.writeInt(
                    source.documentIds.size
                )
                source.documentIds.forEach(
                    output::writeUTF
                )

                output.writeStringMap(
                    source.metadata
                )
                output.writeLong(
                    source.indexedAtMilliseconds
                )
            }
        }

        if (file.exists() && !file.delete()) {
            tempFile.delete()
            throw IllegalStateException(
                "Unable to replace persistent knowledge catalog"
            )
        }

        if (!tempFile.renameTo(file)) {
            tempFile.delete()
            throw IllegalStateException(
                "Unable to finalize persistent knowledge catalog"
            )
        }
    }

    private fun DataInputStream.readStringMap():
        Map<String, String> {
        val count = readInt()
        val values =
            linkedMapOf<String, String>()

        repeat(count) {
            values[readUTF()] = readUTF()
        }

        return values
    }

    private fun DataOutputStream.writeStringMap(
        values: Map<String, String>
    ) {
        writeInt(values.size)
        values.forEach { (key, value) ->
            writeUTF(key)
            writeUTF(value)
        }
    }

    private companion object {
        const val MAGIC = 0x45444341
        const val VERSION = 1
    }
}
