public enum EdgeCapability: String, Hashable, Sendable {
    case textGeneration
    case streaming
    case structuredOutput
    case toolCalling
    case vision
    case audio
    case embeddings
}
