public struct EdgeRAG: Sendable {
    public static let defaultSystemPrompt = """
    Answer using only the supplied local context.
    If the context does not contain enough information, say that the local knowledge does not contain enough information.
    Do not invent facts that are not present in the context.
    """

    private let retriever: EdgeRetriever
    private let agent: EdgeAgent

    public init(
        retriever: EdgeRetriever,
        agent: EdgeAgent
    ) {
        self.retriever = retriever
        self.agent = agent
    }

    public func run(
        query: String,
        in collection: EdgeKnowledgeCollection? = nil,
        topK: Int = 3,
        minimumScore: Float? = nil,
        systemPrompt: String? = nil
    ) async throws -> EdgeRAGResult {
        try await run(
            EdgeRAGRequest(
                query: query,
                collection: collection,
                topK: topK,
                minimumScore: minimumScore,
                systemPrompt: systemPrompt
            )
        )
    }

    public func run(
        _ request: EdgeRAGRequest
    ) async throws -> EdgeRAGResult {
        try Task.checkCancellation()

        let filter = combinedFilter(
            collection: request.collection,
            filter: request.filter
        )

        let retrieved = try await retriever.retrieve(
            query: request.query,
            filter: filter,
            topK: request.topK
        )

        let filtered = if let minimumScore =
            request.minimumScore {
            retrieved.filter {
                $0.score >= minimumScore
            }
        } else {
            retrieved
        }

        let context = Self.buildContext(
            from: filtered
        )

        try Task.checkCancellation()

        let response = try await agent.run(
            EdgeGenerationRequest(
                prompt: Self.buildPrompt(
                    query: request.query,
                    context: context
                ),
                systemPrompt:
                    request.systemPrompt ??
                    Self.defaultSystemPrompt
            )
        )

        return EdgeRAGResult(
            answer: response.text,
            retrievedResults: filtered,
            context: context
        )
    }

    public static func buildContext(
        from results: [EdgeSearchResult]
    ) -> String {
        results
            .enumerated()
            .map { index, result in
                let source =
                    result.chunk.metadata["source"]
                    ?? result.chunk.documentID

                let page =
                    result.chunk.metadata["pageNumber"]
                    .map { " · page \($0)" }
                    ?? ""

                return """
                [\(index + 1)] \(source)\(page)
                \(result.chunk.text)
                """
            }
            .joined(separator: "\n\n")
    }

    public static func buildPrompt(
        query: String,
        context: String
    ) -> String {
        """
        Local context:
        --- BEGIN LOCAL CONTEXT ---
        \(context)
        --- END LOCAL CONTEXT ---

        Question:
        \(query)
        """
    }

    private func combinedFilter(
        collection: EdgeKnowledgeCollection?,
        filter: EdgeVectorFilter?
    ) -> EdgeVectorFilter? {
        guard collection != nil || filter != nil else {
            return nil
        }

        return EdgeVectorFilter(
            documentID: filter?.documentID,
            collectionID:
                collection?.id ??
                filter?.collectionID,
            metadata: filter?.metadata ?? [:]
        )
    }
}
