package io.github.rajibsarwar.edgeframeworks

data class EdgeBenchmarkSample(
    val latencyMilliseconds: Double,
    val memoryDeltaBytes: Long
)

data class EdgeBenchmarkSummary(
    val providerId: String,
    val iterations: Int,
    val averageLatencyMilliseconds: Double,
    val p50LatencyMilliseconds: Double,
    val p95LatencyMilliseconds: Double,
    val averageMemoryDeltaBytes: Double
)

class EdgeBenchmarkRunner {
    suspend fun run(
        provider: EdgeModelProvider,
        request: EdgeGenerationRequest,
        iterations: Int = 5
    ): EdgeBenchmarkSummary {
        require(iterations > 0)

        val samples = buildList {
            repeat(iterations) {
                val memoryBefore = usedHeapBytes()
                val start = System.nanoTime()

                provider.generate(request)

                val elapsedNanos = System.nanoTime() - start
                val memoryAfter = usedHeapBytes()

                add(
                    EdgeBenchmarkSample(
                        latencyMilliseconds =
                            elapsedNanos / 1_000_000.0,
                        memoryDeltaBytes =
                            memoryAfter - memoryBefore
                    )
                )
            }
        }

        val latencies = samples
            .map { it.latencyMilliseconds }
            .sorted()

        return EdgeBenchmarkSummary(
            providerId = provider.id,
            iterations = iterations,
            averageLatencyMilliseconds =
                latencies.average(),
            p50LatencyMilliseconds =
                percentile(latencies, 0.50),
            p95LatencyMilliseconds =
                percentile(latencies, 0.95),
            averageMemoryDeltaBytes =
                samples.map { it.memoryDeltaBytes.toDouble() }.average()
        )
    }

    private fun percentile(
        sortedValues: List<Double>,
        percentile: Double
    ): Double {
        if (sortedValues.isEmpty()) return 0.0

        val index = (
            (sortedValues.lastIndex * percentile)
        ).toInt()

        return sortedValues[index]
    }

    private fun usedHeapBytes(): Long {
        val runtime = Runtime.getRuntime()
        return runtime.totalMemory() - runtime.freeMemory()
    }
}
