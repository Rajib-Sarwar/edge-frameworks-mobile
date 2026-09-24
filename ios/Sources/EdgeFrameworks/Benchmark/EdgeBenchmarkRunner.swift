import Foundation

public struct EdgeBenchmarkSample: Sendable, Equatable {
    public let latencyMilliseconds: Double
    public let memoryDeltaBytes: Int64

    public init(
        latencyMilliseconds: Double,
        memoryDeltaBytes: Int64
    ) {
        self.latencyMilliseconds = latencyMilliseconds
        self.memoryDeltaBytes = memoryDeltaBytes
    }
}

public struct EdgeBenchmarkSummary: Sendable, Equatable {
    public let providerID: String
    public let iterations: Int
    public let averageLatencyMilliseconds: Double
    public let p50LatencyMilliseconds: Double
    public let p95LatencyMilliseconds: Double
    public let averageMemoryDeltaBytes: Double

    public init(
        providerID: String,
        iterations: Int,
        averageLatencyMilliseconds: Double,
        p50LatencyMilliseconds: Double,
        p95LatencyMilliseconds: Double,
        averageMemoryDeltaBytes: Double
    ) {
        self.providerID = providerID
        self.iterations = iterations
        self.averageLatencyMilliseconds = averageLatencyMilliseconds
        self.p50LatencyMilliseconds = p50LatencyMilliseconds
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.averageMemoryDeltaBytes = averageMemoryDeltaBytes
    }
}

public struct EdgeBenchmarkRunner: Sendable {
    public init() {}

    public func run(
        provider: any EdgeModelProvider,
        request: EdgeGenerationRequest,
        iterations: Int = 5
    ) async throws -> EdgeBenchmarkSummary {
        precondition(iterations > 0)

        var samples: [EdgeBenchmarkSample] = []
        samples.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let memoryBefore = currentResidentMemoryBytes()
            let start = ContinuousClock.now

            _ = try await provider.generate(request)

            let duration = start.duration(to: .now)
            let memoryAfter = currentResidentMemoryBytes()

            samples.append(
                EdgeBenchmarkSample(
                    latencyMilliseconds: duration.milliseconds,
                    memoryDeltaBytes: memoryAfter - memoryBefore
                )
            )
        }

        let latencies = samples
            .map(\.latencyMilliseconds)
            .sorted()

        let averageLatency =
            latencies.reduce(0, +) / Double(latencies.count)

        let averageMemory =
            samples
                .map { Double($0.memoryDeltaBytes) }
                .reduce(0, +) / Double(samples.count)

        return EdgeBenchmarkSummary(
            providerID: provider.id,
            iterations: iterations,
            averageLatencyMilliseconds: averageLatency,
            p50LatencyMilliseconds: percentile(latencies, 0.50),
            p95LatencyMilliseconds: percentile(latencies, 0.95),
            averageMemoryDeltaBytes: averageMemory
        )
    }

    private func percentile(
        _ sortedValues: [Double],
        _ percentile: Double
    ) -> Double {
        guard !sortedValues.isEmpty else { return 0 }

        let index = Int(
            (Double(sortedValues.count - 1) * percentile).rounded()
        )

        return sortedValues[index]
    }

    private func currentResidentMemoryBytes() -> Int64 {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size
                / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Int64(info.resident_size)
        #else
        return 0
        #endif
    }
}

private extension Duration {
    var milliseconds: Double {
        let components = self.components

        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
