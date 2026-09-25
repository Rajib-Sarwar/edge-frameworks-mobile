public struct EdgeRetrievalMetrics: Sendable, Equatable {
    public let embeddingMilliseconds: Double
    public let searchMilliseconds: Double
    public let totalMilliseconds: Double
    public let resultCount: Int
    public let topScore: Float?
    public let bottomScore: Float?

    public init(
        embeddingMilliseconds: Double,
        searchMilliseconds: Double,
        totalMilliseconds: Double,
        resultCount: Int,
        topScore: Float?,
        bottomScore: Float?
    ) {
        self.embeddingMilliseconds = embeddingMilliseconds
        self.searchMilliseconds = searchMilliseconds
        self.totalMilliseconds = totalMilliseconds
        self.resultCount = resultCount
        self.topScore = topScore
        self.bottomScore = bottomScore
    }
}

public struct EdgeMeasuredRetrieval: Sendable, Equatable {
    public let results: [EdgeSearchResult]
    public let metrics: EdgeRetrievalMetrics

    public init(
        results: [EdgeSearchResult],
        metrics: EdgeRetrievalMetrics
    ) {
        self.results = results
        self.metrics = metrics
    }
}

public struct EdgeRAGMetrics: Sendable, Equatable {
    public let retrieval: EdgeRetrievalMetrics
    public let generationMilliseconds: Double
    public let totalMilliseconds: Double
    public let requestedTopK: Int
    public let retainedResultCount: Int
    public let contextCharacterCount: Int

    public init(
        retrieval: EdgeRetrievalMetrics,
        generationMilliseconds: Double,
        totalMilliseconds: Double,
        requestedTopK: Int,
        retainedResultCount: Int,
        contextCharacterCount: Int
    ) {
        self.retrieval = retrieval
        self.generationMilliseconds = generationMilliseconds
        self.totalMilliseconds = totalMilliseconds
        self.requestedTopK = requestedTopK
        self.retainedResultCount = retainedResultCount
        self.contextCharacterCount = contextCharacterCount
    }
}
