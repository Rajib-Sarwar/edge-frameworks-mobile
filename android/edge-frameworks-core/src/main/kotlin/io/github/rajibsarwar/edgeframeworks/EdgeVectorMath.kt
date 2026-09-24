package io.github.rajibsarwar.edgeframeworks

import kotlin.math.sqrt

object EdgeVectorMath {
    fun cosineSimilarity(
        left: EdgeEmbedding,
        right: EdgeEmbedding
    ): Float {
        if (left.values.size != right.values.size) {
            throw EdgeVectorException.DimensionMismatch(
                expected = left.values.size,
                actual = right.values.size
            )
        }

        var dot = 0f
        var leftMagnitude = 0f
        var rightMagnitude = 0f

        for (index in left.values.indices) {
            val l = left.values[index]
            val r = right.values[index]
            dot += l * r
            leftMagnitude += l * l
            rightMagnitude += r * r
        }

        if (leftMagnitude <= 0f || rightMagnitude <= 0f) {
            throw EdgeVectorException.ZeroMagnitude
        }

        return dot / (sqrt(leftMagnitude) * sqrt(rightMagnitude))
    }
}
