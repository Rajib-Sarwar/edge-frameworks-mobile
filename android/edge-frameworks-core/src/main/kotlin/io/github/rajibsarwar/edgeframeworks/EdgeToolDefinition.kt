package io.github.rajibsarwar.edgeframeworks

/**
 * Provider-neutral metadata describing a tool and its expected arguments.
 *
 * @property inputSchemaJson A JSON Schema string, stored unchanged without validation.
 */
data class EdgeToolDefinition(
    val name: String,
    val description: String,
    val inputSchemaJson: String
)
