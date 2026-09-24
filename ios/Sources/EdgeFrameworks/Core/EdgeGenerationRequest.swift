public struct EdgeGenerationRequest: Sendable {
    public let prompt: String
    public let systemPrompt: String?

    public init(
        prompt: String,
        systemPrompt: String? = nil
    ) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
    }
}
