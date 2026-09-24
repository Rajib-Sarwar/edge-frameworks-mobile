package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgeBenchmarkRunnerTest {
    @Test
    fun runnerSummarizesProviderIterations() = runTest {
        val summary = EdgeBenchmarkRunner().run(
            provider = BenchmarkTestProvider(),
            request = EdgeGenerationRequest("hello"),
            iterations = 3
        )

        assertEquals("benchmark.test", summary.providerId)
        assertEquals(3, summary.iterations)
        assertTrue(summary.averageLatencyMilliseconds >= 0)
        assertTrue(summary.p50LatencyMilliseconds >= 0)
        assertTrue(summary.p95LatencyMilliseconds >= 0)
    }
}

private class BenchmarkTestProvider : EdgeModelProvider {
    override val id: String = "benchmark.test"

    override suspend fun capabilities(): Set<EdgeCapability> {
        return setOf(EdgeCapability.TEXT_GENERATION)
    }

    override suspend fun generate(
        request: EdgeGenerationRequest
    ): EdgeGenerationResponse {
        return EdgeGenerationResponse(request.prompt)
    }

    override fun stream(
        request: EdgeGenerationRequest
    ): Flow<EdgeGenerationEvent> = emptyFlow()
}
