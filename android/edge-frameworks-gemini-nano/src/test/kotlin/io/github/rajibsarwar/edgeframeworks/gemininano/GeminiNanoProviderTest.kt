package io.github.rajibsarwar.edgeframeworks.gemininano

import io.github.rajibsarwar.edgeframeworks.EdgeCapability
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationEvent
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationRequest
import io.github.rajibsarwar.edgeframeworks.EdgeProviderException
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GeminiNanoProviderTest {
    @Test
    fun advertisesCapabilitiesOnlyWhenAvailable() = runTest {
        val provider = GeminiNanoProvider(
            FakeGeminiNanoClient(status = GeminiNanoStatus.AVAILABLE)
        )

        val capabilities = provider.capabilities()

        assertTrue(capabilities.contains(EdgeCapability.TEXT_GENERATION))
        assertTrue(capabilities.contains(EdgeCapability.STREAMING))
    }

    @Test
    fun downloadableModelIsReportedAsNotReady() = runTest {
        val provider = GeminiNanoProvider(
            FakeGeminiNanoClient(status = GeminiNanoStatus.DOWNLOADABLE)
        )

        try {
            provider.generate(EdgeGenerationRequest(prompt = "Hello"))
            throw AssertionError("Expected ModelNotReady")
        } catch (error: EdgeProviderException.ModelNotReady) {
            assertEquals("google.gemini-nano", error.providerId)
        }
    }

    @Test
    fun unsupportedDeviceIsReportedAsUnavailable() = runTest {
        val provider = GeminiNanoProvider(
            FakeGeminiNanoClient(status = GeminiNanoStatus.UNAVAILABLE)
        )

        try {
            provider.generate(EdgeGenerationRequest(prompt = "Hello"))
            throw AssertionError("Expected ProviderUnavailable")
        } catch (error: EdgeProviderException.ProviderUnavailable) {
            assertEquals("google.gemini-nano", error.providerId)
        }
    }

    @Test
    fun generateReturnsFrameworkResponse() = runTest {
        val provider = GeminiNanoProvider(
            FakeGeminiNanoClient(
                status = GeminiNanoStatus.AVAILABLE,
                generatedText = "Hello from Nano"
            )
        )

        val response = provider.generate(
            EdgeGenerationRequest(prompt = "Hello")
        )

        assertEquals("Hello from Nano", response.text)
    }

    @Test
    fun streamMapsChunksToFrameworkEvents() = runTest {
        val provider = GeminiNanoProvider(
            FakeGeminiNanoClient(
                status = GeminiNanoStatus.AVAILABLE,
                streamedChunks = listOf("Hello ", "from Nano")
            )
        )

        val events = provider.stream(
            EdgeGenerationRequest(prompt = "Hello")
        ).toList()

        assertEquals(
            listOf(
                EdgeGenerationEvent.Started,
                EdgeGenerationEvent.Token("Hello "),
                EdgeGenerationEvent.Token("from Nano"),
                EdgeGenerationEvent.Completed(
                    io.github.rajibsarwar.edgeframeworks.EdgeGenerationResponse(
                        "Hello from Nano"
                    )
                )
            ),
            events
        )
    }
}

private class FakeGeminiNanoClient(
    private val status: GeminiNanoStatus,
    private val generatedText: String = "",
    private val streamedChunks: List<String> = emptyList()
) : GeminiNanoClient {
    override suspend fun status(): GeminiNanoStatus = status

    override suspend fun generate(prompt: String): String = generatedText

    override fun stream(prompt: String) = flowOf(*streamedChunks.toTypedArray())
}
