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
                .structuredOutput
            ]
        default:
            return []
        }
    }

    public func generate(
        _ request: EdgeGenerationRequest
    ) async throws -> EdgeGenerationResponse {
        guard case .available = SystemLanguageModel.default.availability else {
            throw EdgeProviderError.providerUnavailable(providerID: id)
        }

        do {
            try Task.checkCancellation()

            let session = LanguageModelSession(
                instructions: request.systemPrompt ?? ""
            )

            let response = try await session.respond(
                to: request.prompt
            )

            return EdgeGenerationResponse(
                text: response.content
            )
        } catch is CancellationError {
            throw EdgeProviderError.cancelled
        } catch let error as EdgeProviderError {
            throw error
        } catch {
            throw EdgeProviderError.providerFailure(
                providerID: id,
                message: String(describing: error)
            )
        }
    }

    public func generateStructured<Content: Generable>(
        _ request: EdgeGenerationRequest,
        as type: Content.Type = Content.self
    ) async throws -> Content {
        guard case .available = SystemLanguageModel.default.availability else {
            throw EdgeProviderError.providerUnavailable(providerID: id)
        }

        do {
            try Task.checkCancellation()

            let session = LanguageModelSession(
                instructions: request.systemPrompt ?? ""
            )

            let response = try await session.respond(
                to: request.prompt,
                generating: type
            )

            return response.content
        } catch is CancellationError {
            throw EdgeProviderError.cancelled
        } catch let error as EdgeProviderError {
            throw error
        } catch {
            throw EdgeProviderError.providerFailure(
                providerID: id,
                message: String(describing: error)
            )
        }
    }

    public func stream(
        _ request: EdgeGenerationRequest
    ) -> AsyncThrowingStream<EdgeGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard case .available = SystemLanguageModel.default.availability else {
                    continuation.finish(
                        throwing: EdgeProviderError.providerUnavailable(
                            providerID: id
                        )
                    )
                    return
                }

                do {
                    try Task.checkCancellation()
                    continuation.yield(.started)

                    let session = LanguageModelSession(
                        instructions: request.systemPrompt ?? ""
                    )

                    var previous = ""

                    for try await snapshot in session.streamResponse(
                        to: request.prompt
                    ) {
                        try Task.checkCancellation()

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
                } catch is CancellationError {
                    continuation.finish(
                        throwing: EdgeProviderError.cancelled
                    )
                } catch let error as EdgeProviderError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(
                        throwing: EdgeProviderError.providerFailure(
                            providerID: id,
                            message: String(describing: error)
                        )
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
#endif
