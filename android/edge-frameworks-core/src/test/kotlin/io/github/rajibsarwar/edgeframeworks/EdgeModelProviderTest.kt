package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgeModelProviderTest {
    @Test
    fun providerGeneratesAndStreams() = runTest {
        val provider = MockProvider()

        val capabilities = provider.capabilities()
        assertTrue(capabilities.contains(EdgeCapability.TEXT_GENERATION))
        assertTrue(capabilities.contains(EdgeCapability.STREAMING))

        val request = EdgeGenerationRequest(prompt = "Hello")
        val response = provider.generate(request)
        assertEquals(EdgeGenerationResponse("Hello from mock"), response)

        val events = provider.stream(request).toList()

        assertEquals(
            listOf(
                EdgeGenerationEvent.Started,
                EdgeGenerationEvent.Token("Hello "),
                EdgeGenerationEvent.Token("from mock"),
                EdgeGenerationEvent.Completed(
                    EdgeGenerationResponse("Hello from mock")
                )
            ),
            events
        )
    }
}

private class MockProvider : EdgeModelProvider {
    override val id = "mock"

    override suspend fun capabilities(): Set<EdgeCapability> {
        return setOf(
            EdgeCapability.TEXT_GENERATION,
            EdgeCapability.STREAMING
        )
    }

    override suspend fun generate(
        request: EdgeGenerationRequest
    ): EdgeGenerationResponse {
        return EdgeGenerationResponse("Hello from mock")
    }

    override fun stream(
        request: EdgeGenerationRequest
    ) = flow {
        emit(EdgeGenerationEvent.Started)
        emit(EdgeGenerationEvent.Token("Hello "))
        emit(EdgeGenerationEvent.Token("from mock"))
        emit(
            EdgeGenerationEvent.Completed(
                EdgeGenerationResponse("Hello from mock")
            )
        )
    }
}
