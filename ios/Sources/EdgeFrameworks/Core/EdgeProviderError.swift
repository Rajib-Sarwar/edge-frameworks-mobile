import Foundation

public enum EdgeProviderError: Error, Sendable, Equatable {
    case providerUnavailable(providerID: String)
    case modelNotReady(providerID: String)
    case unsupportedCapability(EdgeCapability)
    case contextLimitExceeded
    case cancelled
    case rateLimited
    case providerFailure(providerID: String, message: String)
}
