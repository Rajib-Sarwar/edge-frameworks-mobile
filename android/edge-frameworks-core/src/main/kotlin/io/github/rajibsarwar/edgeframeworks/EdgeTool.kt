package io.github.rajibsarwar.edgeframeworks

/** A provider-neutral asynchronous operation exposed as a tool. */
interface EdgeTool {
    val definition: EdgeToolDefinition

    /**
     * Executes the tool with JSON-encoded arguments.
     *
     * Implementations decode and validate arguments and throw on failure.
     * Provider registration and model-driven dispatch belong to provider adapters.
     */
    suspend fun call(argumentsJson: String): EdgeToolResult
}
