package io.github.rajibsarwar.edgeframeworks.gemininano

import io.github.rajibsarwar.edgeframeworks.EdgeCapability
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationEvent
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationRequest
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationResponse
import io.github.rajibsarwar.edgeframeworks.EdgeProviderException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.flow
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
    fun mapsDownloadProgressToPublicState() = runTest {
        val provider = GeminiNanoProvider(
            FakeGeminiNanoClient(
                status = GeminiNanoStatus.DOWNLOADABLE,
                downloadEvents = listOf(
                    GeminiNanoDownloadEvent.Started,
                    GeminiNanoDownloadEvent.Progress(1_048_576),
                    GeminiNanoDownloadEvent.Completed
                )
            )
        )

        val states = provider.download().toList()

        assertEquals(
            listOf(
                GeminiNanoDownloadState.Started,
                GeminiNanoDownloadState.Progress(1_048_576),
                GeminiNanoDownloadState.Completed
            ),
            states
        )
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
    fun generationCancellationMapsToFrameworkError() = runTest {
        val provider = GeminiNanoProvider(
            FakeGeminiNanoClient(
                status = GeminiNanoStatus.AVAILABLE,
                cancelGeneration = true
            )
        )

        try {
            provider.generate(EdgeGenerationRequest(prompt = "Hello"))
            throw AssertionError("Expected Cancelled")
        } catch (_: EdgeProviderException.Cancelled) {
            // expected
        }
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
                    EdgeGenerationResponse("Hello from Nano")
                )
            ),
            events
        )
    }
}

private class FakeGeminiNanoClient(
    private val status: GeminiNanoStatus,
    private val generatedText: String = "",
    private val streamedChunks: List<String> = emptyList(),
    private val downloadEvents: List<GeminiNanoDownloadEvent> = emptyList(),
    private val cancelGeneration: Boolean = false
) : GeminiNanoClient {
    override suspend fun status(): GeminiNanoStatus = status

    override fun download() =
        flowOf(*downloadEvents.toTypedArray())

    override suspend fun generate(prompt: String): String {
        if (cancelGeneration) {
            throw CancellationException("cancelled")
        }

        return generatedText
    }

    override fun stream(prompt: String) = if (cancelGeneration) {
        flow<String> {
            throw CancellationException("cancelled")
        }
    } else {
        flowOf(*streamedChunks.toTypedArray())
    }
}
