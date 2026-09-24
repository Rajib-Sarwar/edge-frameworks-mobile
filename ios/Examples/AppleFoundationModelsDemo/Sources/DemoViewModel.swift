import EdgeFrameworks
import Foundation
import FoundationModels
import UIKit

@Generable
struct StructuredSummary {
    let title: String
    let bullets: [String]
}

@MainActor
final class DemoViewModel: ObservableObject {
    @Published var prompt = "Explain on-device AI in three short bullets."
    @Published var output = ""
    @Published var structuredOutput = ""
    @Published var status = "Checking on-device model…"
    @Published var benchmarkOutput = ""
    @Published var isRunning = false
    @Published var isStructuredRunning = false
    @Published var isBenchmarking = false
    @Published var isAvailable = false

    private var agent: EdgeAgent?
    private var provider: AppleFoundationModelProvider?

    init() {
        configure()
    }

    func configure() {
        guard #available(iOS 26.0, *) else {
            status = "Apple Foundation Models requires iOS 26 or newer."
            return
        }

        let provider = AppleFoundationModelProvider()
        self.provider = provider

        let router = EdgeProviderRouter(providers: [provider])
        agent = EdgeAgent(router: router)

        Task {
            let capabilities = await provider.capabilities()
            isAvailable = capabilities.contains(.textGeneration)

            status = isAvailable
                ? "Foundation Models is ready · running locally."
                : "Foundation Models is not available on this device."
        }
    }

    func run() {
        guard let agent else { return }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isRunning = true
        output = ""
        status = "Generating on device…"

        Task {
            defer { isRunning = false }

            do {
                let stream = try await agent.stream(
                    EdgeGenerationRequest(
                        prompt: trimmedPrompt,
                        systemPrompt: "Answer clearly and concisely."
                    )
                )

                for try await event in stream {
                    switch event {
                    case .started:
                        status = "Generating on device…"

                    case .token(let token):
                        output += token

                    case .completed:
                        status = "Completed locally."
                    }
                }
            } catch {
                status = "Generation failed."
                output = String(describing: error)
            }
        }
    }

    func runStructured() {
        guard
            #available(iOS 26.0, *),
            let provider
        else {
            return
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isStructuredRunning = true
        structuredOutput = ""
        status = "Generating structured output…"

        Task {
            defer { isStructuredRunning = false }

            do {
                let result = try await provider.generateStructured(
                    EdgeGenerationRequest(
                        prompt: trimmedPrompt,
                        systemPrompt: "Return a concise title and exactly three short bullets."
                    ),
                    as: StructuredSummary.self
                )

                let bullets = result.bullets
                    .map { "• \($0)" }
                    .joined(separator: "\n")

                structuredOutput = """
                \(result.title)

                \(bullets)
                """
                status = "Structured output completed locally."
            } catch {
                status = "Structured generation failed."
                structuredOutput = String(describing: error)
            }
        }
    }

    func runBenchmark() {
        guard
            #available(iOS 26.0, *),
            let provider
        else {
            return
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isBenchmarking = true
        benchmarkOutput = ""
        status = "Warming up model…"

        Task {
            defer { isBenchmarking = false }

            do {
                let request = EdgeGenerationRequest(
                    prompt: trimmedPrompt,
                    systemPrompt: "Answer clearly and concisely."
                )

                _ = try await provider.generate(request)

                status = "Running 10 benchmark iterations…"

                let summary = try await EdgeBenchmarkRunner().run(
                    provider: provider,
                    request: request,
                    iterations: 10
                )

                benchmarkOutput = formatBenchmark(summary)
                status = "Benchmark completed."
            } catch {
                status = "Benchmark failed."
                benchmarkOutput = String(describing: error)
            }
        }
    }

    private func formatBenchmark(
        _ summary: EdgeBenchmarkSummary
    ) -> String {
        """
        Device: \(UIDevice.current.model)
        OS: iOS \(UIDevice.current.systemVersion)
        Provider: \(summary.providerID)
        Iterations: \(summary.iterations)
        Warm-up: 1 unmeasured request

        Average latency: \(summary.averageLatencyMilliseconds.formatted(.number.precision(.fractionLength(1)))) ms
        P50 latency: \(summary.p50LatencyMilliseconds.formatted(.number.precision(.fractionLength(1)))) ms
        P95 latency: \(summary.p95LatencyMilliseconds.formatted(.number.precision(.fractionLength(1)))) ms
        Average memory delta: \((summary.averageMemoryDeltaBytes / 1_048_576).formatted(.number.precision(.fractionLength(2)))) MB
        """
    }
}
