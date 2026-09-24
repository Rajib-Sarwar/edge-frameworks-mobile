/// Provider-neutral metadata describing a tool and its expected arguments.
public struct EdgeToolDefinition: Hashable, Sendable {
    public let name: String
    public let description: String
    /// A JSON Schema string. The core stores it unchanged without validation.
    public let inputSchemaJSON: String

    public init(name: String, description: String, inputSchemaJSON: String) {
        self.name = name
        self.description = description
        self.inputSchemaJSON = inputSchemaJSON
    }
}
