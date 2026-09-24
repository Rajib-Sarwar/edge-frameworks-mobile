/// A provider-neutral asynchronous operation exposed as a tool.
public protocol EdgeTool: Sendable {
    var definition: EdgeToolDefinition { get }

    /// Executes the tool with JSON-encoded arguments.
    ///
    /// Implementations decode and validate arguments and throw on failure.
    /// Provider registration and model-driven dispatch belong to provider adapters.
    func call(argumentsJSON: String) async throws -> EdgeToolResult
}
