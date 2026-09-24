/// Text returned by a tool. Content may contain plain text or serialized JSON.
public struct EdgeToolResult: Equatable, Sendable {
    public let content: String

    public init(content: String) {
        self.content = content
    }
}
