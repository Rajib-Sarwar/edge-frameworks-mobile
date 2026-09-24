import XCTest
import EdgeFrameworks

final class EdgeToolTests: XCTestCase {
    func testDefinitionPreservesMetadataAndHasValueSemantics() {
        let tool: any EdgeTool = EchoTool()
        let expected = EdgeToolDefinition(
            name: "echo",
            description: "Returns JSON arguments unchanged.",
            inputSchemaJSON: #"{"type":"object"}"#
        )

        XCTAssertEqual(tool.definition.name, "echo")
        XCTAssertEqual(tool.definition.description, "Returns JSON arguments unchanged.")
        XCTAssertEqual(tool.definition.inputSchemaJSON, #"{"type":"object"}"#)
        XCTAssertEqual(tool.definition, expected)
        XCTAssertEqual(Set([tool.definition, expected]).count, 1)
        XCTAssertNotEqual(expected, EdgeToolDefinition(
            name: "other",
            description: expected.description,
            inputSchemaJSON: expected.inputSchemaJSON
        ))
    }

    func testToolCanBeCalledThroughProtocol() async throws {
        let tool: any EdgeTool = EchoTool()
        let arguments = #"{"message":"Hello, 世界","count":2}"#

        let result = try await tool.call(argumentsJSON: arguments)

        XCTAssertEqual(result.content, arguments)
        XCTAssertEqual(result, EdgeToolResult(content: arguments))
        XCTAssertNotEqual(result, EdgeToolResult(content: "different"))
    }

    func testToolFailurePropagates() async {
        let tool: any EdgeTool = FailingTool()

        do {
            _ = try await tool.call(argumentsJSON: "{}")
            XCTFail("Expected tool failure")
        } catch {
            XCTAssertEqual(error as? TestToolError, .invalidArguments)
        }
    }
}

private struct EchoTool: EdgeTool {
    let definition = EdgeToolDefinition(
        name: "echo",
        description: "Returns JSON arguments unchanged.",
        inputSchemaJSON: #"{"type":"object"}"#
    )

    func call(argumentsJSON: String) async throws -> EdgeToolResult {
        await Task.yield()
        return EdgeToolResult(content: argumentsJSON)
    }
}

private enum TestToolError: Error {
    case invalidArguments
}

private struct FailingTool: EdgeTool {
    let definition = EchoTool().definition

    func call(argumentsJSON: String) async throws -> EdgeToolResult {
        await Task.yield()
        throw TestToolError.invalidArguments
    }
}
