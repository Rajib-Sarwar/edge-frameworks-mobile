#if canImport(FoundationModels)
import Foundation
import FoundationModels
import XCTest
@testable import EdgeFrameworks

@available(iOS 26.0, macOS 26.0, *)
final class AppleFoundationModelToolAdapterTests: XCTestCase {
    func testAdapterPreservesToolMetadataAndForwardsJSONArguments() async throws {
        let tool = RecordingTool()
        let adapter = try AppleFoundationModelToolAdapter(tool: tool)

        XCTAssertEqual(adapter.name, "lookupWeather")
        XCTAssertEqual(adapter.description, "Looks up weather for a city.")

        let arguments = try GeneratedContent(
            json: #"{"city":"New York","days":2}"#
        )

        let output = try await adapter.call(arguments: arguments)

        let outputObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(output.utf8)
            ) as? NSDictionary
        )

        let expectedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(#"{"city":"New York","days":2}"#.utf8)
            ) as? NSDictionary
        )

        XCTAssertEqual(outputObject, expectedObject)
    }

    func testAdapterSupportsCommonJSONSchemaTypes() throws {
        _ = try AppleFoundationModelToolAdapter(
            tool: SchemaTool(
                schema: """
                {
                  "type": "object",
                  "required": ["city", "days", "metric", "includeHourly", "tags"],
                  "properties": {
                    "city": {"type": "string"},
                    "days": {"type": "integer"},
                    "metric": {"type": "number"},
                    "includeHourly": {"type": "boolean"},
                    "tags": {
                      "type": "array",
                      "items": {"type": "string"},
                      "minItems": 1,
                      "maxItems": 3
                    }
                  }
                }
                """
            )
        )
    }

    func testAdapterRejectsUnsupportedSchemaType() {
        XCTAssertThrowsError(
            try AppleFoundationModelToolAdapter(
                tool: SchemaTool(
                    schema: #"{"type":"null"}"#
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? AppleFoundationModelToolAdapterError,
                .unsupportedSchemaType("null")
            )
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private actor RecordingTool: EdgeTool {
    nonisolated let definition = EdgeToolDefinition(
        name: "lookupWeather",
        description: "Looks up weather for a city.",
        inputSchemaJSON: """
        {
          "type": "object",
          "required": ["city", "days"],
          "properties": {
            "city": {"type": "string"},
            "days": {"type": "integer"}
          }
        }
        """
    )

    func call(argumentsJSON: String) async throws -> EdgeToolResult {
        EdgeToolResult(content: argumentsJSON)
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct SchemaTool: EdgeTool {
    let schema: String

    var definition: EdgeToolDefinition {
        EdgeToolDefinition(
            name: "schemaTest",
            description: "Exercises schema compilation.",
            inputSchemaJSON: schema
        )
    }

    func call(argumentsJSON: String) async throws -> EdgeToolResult {
        EdgeToolResult(content: argumentsJSON)
    }
}
#endif
