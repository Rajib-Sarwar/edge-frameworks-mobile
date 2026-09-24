package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

class EdgeProviderRouterTest {
    @Test
    fun selectsProviderMatchingRequiredCapabilities() = runTest {
        val textOnly = RouterMockProvider(
            id = "text-only",
            supportedCapabilities = setOf(
                EdgeCapability.TEXT_GENERATION
            )
        )
        val streaming = RouterMockProvider(
            id = "streaming",
            supportedCapabilities = setOf(
                EdgeCapability.TEXT_GENERATION,
                EdgeCapability.STREAMING
            )
        )

        val router = EdgeProviderRouter(
            listOf(textOnly, streaming)
        )

        val selected = router.provider(
            setOf(
                EdgeCapability.TEXT_GENERATION,
                EdgeCapability.STREAMING
            )
        )

        assertEquals("streaming", selected?.id)
    }

    @Test
    fun agentFailsWhenNoProviderMatches() = runTest {
        val agent = EdgeAgent(EdgeProviderRouter())

        try {
            agent.run(
                EdgeGenerationRequest(prompt = "Hello")
            )
            fail("Expected NoCompatibleProvider")
        } catch (error: EdgeAgentException.NoCompatibleProvider) {
            // expected
        }
    }
}

private class RouterMockProvider(
    override val id: String,
    private val supportedCapabilities: Set<EdgeCapability>
) : EdgeModelProvider {
    override suspend fun capabilities(): Set<EdgeCapability> {
        return supportedCapabilities
    }

    override suspend fun generate(
        request: EdgeGenerationRequest
    ): EdgeGenerationResponse {
        return EdgeGenerationResponse(request.prompt)
    }

    override fun stream(
        request: EdgeGenerationRequest
    ) = flow {
        emit(EdgeGenerationEvent.Started)
        emit(
            EdgeGenerationEvent.Completed(
                EdgeGenerationResponse(request.prompt)
            )
        )
    }
}
