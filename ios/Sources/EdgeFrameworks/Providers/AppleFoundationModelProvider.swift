#if canImport(FoundationModels)
import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
public struct AppleFoundationModelProvider: EdgeModelProvider {
    public let id = "apple.foundation-models"

    public init() {}

    public func capabilities() async -> Set<EdgeCapability> {
        switch SystemLanguageModel.default.availability {
        case .available:
            return [
                .textGeneration,
                .streaming,
                .structuredOutput,
                .toolCalling
            ]
        case .unavailable:
            return []
        }
    }

    public func generate(
        _ request: EdgeGenerationRequest
    ) async throws -> EdgeGenerationResponse {
        let session = LanguageModelSession(
            instructions: request.systemPrompt ?? ""
        )

        let response = try await session.respond(
            to: request.prompt
        )

        return EdgeGenerationResponse(
            text: response.content
        )
    }

    public func stream(
        _ request: EdgeGenerationRequest
    ) -> AsyncThrowingStream<EdgeGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.started)

                    let session = LanguageModelSession(
                        instructions: request.systemPrompt ?? ""
                    )

                    var previous = ""

                    for try await snapshot in session.streamResponse(
                        to: request.prompt
                    ) {
                        let current = snapshot.content

                        if current.hasPrefix(previous) {
                            let delta = String(
                                current.dropFirst(previous.count)
                            )

                            if !delta.isEmpty {
                                continuation.yield(.token(delta))
                            }
                        } else if current != previous {
                            continuation.yield(.token(current))
                        }

                        previous = current
                    }

                    continuation.yield(
                        .completed(
                            EdgeGenerationResponse(text: previous)
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
#endif
