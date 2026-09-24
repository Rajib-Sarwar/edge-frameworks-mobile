public struct EdgeDocument: Equatable, Sendable {
    public let id: String
    public let text: String
    public let metadata: [String: String]

    public init(
        id: String,
        text: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.metadata = metadata
    }
}

public struct EdgeChunk: Equatable, Sendable {
    public let id: String
    public let documentID: String
    public let text: String
    public let metadata: [String: String]

    public init(
        id: String,
        documentID: String,
        text: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.documentID = documentID
        self.text = text
        self.metadata = metadata
    }
}

public struct EdgeEmbedding: Equatable, Sendable {
    public let values: [Float]

    public init(values: [Float]) {
        self.values = values
    }
}

public struct EdgeSearchResult: Equatable, Sendable {
    public let chunk: EdgeChunk
    public let score: Float

    public init(chunk: EdgeChunk, score: Float) {
        self.chunk = chunk
        self.score = score
    }
}

public enum EdgeVectorError: Error, Equatable, Sendable {
    case dimensionMismatch(expected: Int, actual: Int)
    case countMismatch(expected: Int, actual: Int)
    case zeroMagnitude
}
