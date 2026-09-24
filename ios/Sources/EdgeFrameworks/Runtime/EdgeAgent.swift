import Foundation

public enum EdgeAgentError: Error, Equatable {
    case noCompatibleProvider
}

public struct EdgeAgent: Sendable {
    private let router: EdgeProviderRouter

    public init(router: EdgeProviderRouter) {
        self.router = router
    }

    public func run(
        _ request: EdgeGenerationRequest,
        requiring capabilities: Set<EdgeCapability> = [.textGeneration]
    ) async throws -> EdgeGenerationResponse {
        guard let provider = await router.provider(supporting: capabilities) else {
            throw EdgeAgentError.noCompatibleProvider
        }

        return try await provider.generate(request)
    }

    public func stream(
        _ request: EdgeGenerationRequest,
        requiring capabilities: Set<EdgeCapability> = [.textGeneration, .streaming]
    ) async throws -> AsyncThrowingStream<EdgeGenerationEvent, Error> {
        guard let provider = await router.provider(supporting: capabilities) else {
            throw EdgeAgentError.noCompatibleProvider
        }

        return provider.stream(request)
    }
}
