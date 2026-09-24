import EdgeFrameworks
import Foundation

@MainActor
final class DemoViewModel: ObservableObject {
    @Published var prompt = "Explain on-device AI in three short bullets."
    @Published var output = ""
    @Published var status = "Checking on-device model…"
    @Published var isRunning = false
    @Published var isAvailable = false

    private var agent: EdgeAgent?

    init() {
        configure()
    }

    func configure() {
        guard #available(iOS 26.0, *) else {
            status = "Apple Foundation Models requires iOS 26 or newer."
            return
        }

        let provider = AppleFoundationModelProvider()
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
}
