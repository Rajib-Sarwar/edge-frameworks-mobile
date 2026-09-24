import Foundation

public enum EdgeVectorMath {
    public static func cosineSimilarity(
        _ lhs: EdgeEmbedding,
        _ rhs: EdgeEmbedding
    ) throws -> Float {
        guard lhs.values.count == rhs.values.count else {
            throw EdgeVectorError.dimensionMismatch(
                expected: lhs.values.count,
                actual: rhs.values.count
            )
        }

        var dot: Float = 0
        var lhsMagnitude: Float = 0
        var rhsMagnitude: Float = 0

        for (left, right) in zip(lhs.values, rhs.values) {
            dot += left * right
            lhsMagnitude += left * left
            rhsMagnitude += right * right
        }

        guard lhsMagnitude > 0, rhsMagnitude > 0 else {
            throw EdgeVectorError.zeroMagnitude
        }

        return dot / (sqrt(lhsMagnitude) * sqrt(rhsMagnitude))
    }
}
