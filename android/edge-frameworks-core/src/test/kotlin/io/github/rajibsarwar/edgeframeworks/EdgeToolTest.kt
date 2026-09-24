package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertSame
import org.junit.Assert.fail
import org.junit.Test

class EdgeToolTest {
    @Test
    fun definitionPreservesMetadataAndHasValueSemantics() {
        val tool: EdgeTool = EchoTool()
        val expected = EdgeToolDefinition(
            name = "echo",
            description = "Returns JSON arguments unchanged.",
            inputSchemaJson = """{"type":"object"}"""
        )

        assertEquals("echo", tool.definition.name)
        assertEquals("Returns JSON arguments unchanged.", tool.definition.description)
        assertEquals("""{"type":"object"}""", tool.definition.inputSchemaJson)
        assertEquals(expected, tool.definition)
        assertEquals(1, setOf(tool.definition, expected).size)
        assertNotEquals(expected, expected.copy(name = "other"))
    }

    @Test
    fun toolCanBeCalledThroughInterface() = runTest {
        val tool: EdgeTool = EchoTool()
        val arguments = """{"message":"Hello, 世界","count":2}"""

        val result = tool.call(arguments)

        assertEquals(arguments, result.content)
        assertEquals(EdgeToolResult(arguments), result)
        assertNotEquals(EdgeToolResult("different"), result)
    }

    @Test
    fun toolFailurePropagates() = runTest {
        val failure = IllegalArgumentException("Invalid arguments")
        val tool: EdgeTool = FailingTool(failure)

        try {
            tool.call("{}")
            fail("Expected tool failure")
        } catch (error: IllegalArgumentException) {
            assertSame(failure, error)
        }
    }
}

private class EchoTool : EdgeTool {
    override val definition = EdgeToolDefinition(
        name = "echo",
        description = "Returns JSON arguments unchanged.",
        inputSchemaJson = """{"type":"object"}"""
    )

    override suspend fun call(argumentsJson: String): EdgeToolResult {
        yield()
        return EdgeToolResult(argumentsJson)
    }
}

private class FailingTool(private val failure: IllegalArgumentException) : EdgeTool {
    override val definition = EchoTool().definition

    override suspend fun call(argumentsJson: String): EdgeToolResult {
        yield()
        throw failure
    }
}
