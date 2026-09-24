public enum EdgeGenerationEvent: Sendable, Equatable {
    case started
    case token(String)
    case completed(EdgeGenerationResponse)
}
