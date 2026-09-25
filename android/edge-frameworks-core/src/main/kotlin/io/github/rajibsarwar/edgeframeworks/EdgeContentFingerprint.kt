package io.github.rajibsarwar.edgeframeworks

import java.security.MessageDigest

object EdgeContentFingerprint {
    fun sha256(
        bytes: ByteArray
    ): String {
        return MessageDigest
            .getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") {
                "%02x".format(
                    it.toInt() and 0xff
                )
            }
    }

    fun sha256(
        text: String
    ): String {
        return sha256(
            text.toByteArray(Charsets.UTF_8)
        )
    }
}
