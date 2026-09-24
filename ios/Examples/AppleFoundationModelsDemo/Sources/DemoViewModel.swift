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

    @Published var ragQuestion = "When does my Tokyo flight leave?"
    @Published var ragStatus = "Preparing local knowledge…"
    @Published var ragRetrievedOutput = ""
    @Published var ragAnswer = ""
    @Published var isRAGRunning = false
    @Published var isRAGReady = false

    private var agent: EdgeAgent?
    private var provider: AppleFoundationModelProvider?
    private var ragRetriever: EdgeRetriever?

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

            await configureLocalRAG()
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

    func runRAG() {
        guard
            #available(iOS 26.0, *),
            let provider,
            let ragRetriever
        else {
            return
        }

        let question = ragQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        isRAGRunning = true
        ragRetrievedOutput = ""
        ragAnswer = ""
        ragStatus = "Retrieving relevant chunks locally…"

        Task {
            defer { isRAGRunning = false }

            do {
                let results = try await ragRetriever.retrieve(
                    query: question,
                    topK: 3
                )

                ragRetrievedOutput = results
                    .enumerated()
                    .map { index, result in
                        let score = result.score.formatted(
                            .number.precision(.fractionLength(3))
                        )
                        return "\(index + 1). [\(score)] \(result.chunk.text)"
                    }
                    .joined(separator: "\n\n")

                let context = results
                    .map(\.chunk.text)
                    .joined(separator: "\n")

                ragStatus = "Generating answer from retrieved local context…"

                let response = try await provider.generate(
                    EdgeGenerationRequest(
                        prompt: """
                        Local context:
                        \(context)

                        Question:
                        \(question)
                        """,
                        systemPrompt: """
                        Answer using only the supplied local context. If the context does not contain
                        the answer, say that the local knowledge does not contain enough information.
                        """
                    )
                )

                ragAnswer = response.text
                ragStatus = "RAG completed locally · no network required."
            } catch {
                ragStatus = "Local RAG failed."
                ragAnswer = String(describing: error)
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

    private func configureLocalRAG() async {
        do {
            let embeddingProvider = try AppleNaturalLanguageEmbeddingProvider()
            let vectorStore = EdgeInMemoryVectorStore()
            let retriever = EdgeRetriever(
                embeddingProvider: embeddingProvider,
                vectorStore: vectorStore
            )

            try await retriever.index(Self.demoChunks)
            ragRetriever = retriever
            isRAGReady = true
            ragStatus = "Indexed \(Self.demoChunks.count) chunks locally."
        } catch {
            isRAGReady = false
            ragStatus = "Local embeddings unavailable: \(error)"
        }
    }

    private static let demoChunks: [EdgeChunk] = [
        EdgeChunk(
            id: "travel-flight",
            documentID: "travel-notes",
            text: "Our flight to Tokyo leaves Newark on October 12 at 9:30 AM."
        ),
        EdgeChunk(
            id: "travel-hotel",
            documentID: "travel-notes",
            text: "We are staying at the Shinagawa Prince Hotel in Tokyo for four nights."
        ),
        EdgeChunk(
            id: "travel-train",
            documentID: "travel-notes",
            text: "The airport train reservation is for the Narita Express after landing."
        ),
        EdgeChunk(
            id: "insurance",
            documentID: "personal-notes",
            text: "The new insurance coverage begins on November 1."
        ),
        EdgeChunk(
            id: "dinner",
            documentID: "personal-notes",
            text: "Friday dinner is reserved at an Italian restaurant at 7:00 PM."
        )
    ]

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
