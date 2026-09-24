import Foundation

public protocol EdgeModelProvider: Sendable {
    var id: String { get }

    func capabilities() async -> Set<EdgeCapability>

    func generate(_ request: EdgeGenerationRequest) async throws -> EdgeGenerationResponse

    func stream(_ request: EdgeGenerationRequest) -> AsyncThrowingStream<EdgeGenerationEvent, Error>
}
