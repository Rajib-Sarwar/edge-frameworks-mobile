#if canImport(FoundationModels)
import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
public enum AppleFoundationModelToolAdapterError: Error, Equatable {
    case invalidJSONSchema
    case unsupportedSchemaType(String)
    case missingArrayItems
}

@available(iOS 26.0, macOS 26.0, *)
public struct AppleFoundationModelToolAdapter: Tool {
    public typealias Arguments = GeneratedContent
    public typealias Output = String

    public let name: String
    public let description: String
    public let parameters: GenerationSchema

    private let edgeTool: any EdgeTool

    public init(tool: any EdgeTool) throws {
        self.edgeTool = tool
        self.name = tool.definition.name
        self.description = tool.definition.description
        self.parameters = try Self.makeGenerationSchema(
            from: tool.definition.inputSchemaJSON,
            rootName: Self.schemaName(from: tool.definition.name)
        )
    }

    public func call(arguments: GeneratedContent) async throws -> String {
        let result = try await edgeTool.call(
            argumentsJSON: arguments.jsonString
        )
        return result.content
    }

    private static func makeGenerationSchema(
        from jsonSchema: String,
        rootName: String
    ) throws -> GenerationSchema {
        guard
            let data = jsonSchema.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw AppleFoundationModelToolAdapterError.invalidJSONSchema
        }

        let root = try dynamicSchema(
            from: object,
            objectName: rootName
        )

        return try GenerationSchema(
            root: root,
            dependencies: []
        )
    }

    private static func dynamicSchema(
        from schema: [String: Any],
        objectName: String
    ) throws -> DynamicGenerationSchema {
        guard let type = schema["type"] as? String else {
            throw AppleFoundationModelToolAdapterError.invalidJSONSchema
        }

        switch type {
        case "object":
            let required = Set(schema["required"] as? [String] ?? [])
            let propertiesObject = schema["properties"] as? [String: Any] ?? [:]

            let properties = try propertiesObject
                .sorted { $0.key < $1.key }
                .map { name, value -> DynamicGenerationSchema.Property in
                    guard let childSchema = value as? [String: Any] else {
                        throw AppleFoundationModelToolAdapterError.invalidJSONSchema
                    }

                    let child = try dynamicSchema(
                        from: childSchema,
                        objectName: "\(objectName)_\(name)"
                    )

                    return DynamicGenerationSchema.Property(
                        name: name,
                        description: childSchema["description"] as? String,
                        schema: child,
                        isOptional: !required.contains(name)
                    )
                }

            return DynamicGenerationSchema(
                name: objectName,
                description: schema["description"] as? String,
                properties: properties
            )

        case "string":
            return DynamicGenerationSchema(type: String.self)

        case "integer":
            return DynamicGenerationSchema(type: Int.self)

        case "number":
            return DynamicGenerationSchema(type: Double.self)

        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)

        case "array":
            guard let items = schema["items"] as? [String: Any] else {
                throw AppleFoundationModelToolAdapterError.missingArrayItems
            }

            return DynamicGenerationSchema(
                arrayOf: try dynamicSchema(
                    from: items,
                    objectName: "\(objectName)_Item"
                ),
                minimumElements: schema["minItems"] as? Int,
                maximumElements: schema["maxItems"] as? Int
            )

        default:
            throw AppleFoundationModelToolAdapterError.unsupportedSchemaType(type)
        }
    }

    private static func schemaName(from toolName: String) -> String {
        let scalars = toolName.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(String(scalar))
            }
            return "_"
        }

        let value = String(scalars)
        return value.isEmpty ? "EdgeToolArguments" : "\(value)Arguments"
    }
}
#endif
