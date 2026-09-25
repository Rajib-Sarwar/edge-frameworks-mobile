public struct EdgeRAGRequest: Sendable {
    public let query: String
    public let collection: EdgeKnowledgeCollection?
    public let filter: EdgeVectorFilter?
    public let topK: Int
    public let minimumScore: Float?
    public let systemPrompt: String?

    public init(
        query: String,
        collection: EdgeKnowledgeCollection? = nil,
        filter: EdgeVectorFilter? = nil,
        topK: Int = 3,
        minimumScore: Float? = nil,
        systemPrompt: String? = nil
    ) {
        self.query = query
        self.collection = collection
        self.filter = filter
        self.topK = topK
        self.minimumScore = minimumScore
        self.systemPrompt = systemPrompt
    }
}

public struct EdgeRAGResult: Sendable, Equatable {
    public let answer: String
    public let retrievedResults: [EdgeSearchResult]
    public let context: String

    public init(
        answer: String,
        retrievedResults: [EdgeSearchResult],
        context: String
    ) {
        self.answer = answer
        self.retrievedResults = retrievedResults
        self.context = context
    }
}
