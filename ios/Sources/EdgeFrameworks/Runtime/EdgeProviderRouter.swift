import Foundation

public actor EdgeProviderRouter {
    private var providers: [any EdgeModelProvider]

    public init(providers: [any EdgeModelProvider] = []) {
        self.providers = providers
    }

    public func register(_ provider: any EdgeModelProvider) {
        providers.removeAll { $0.id == provider.id }
        providers.append(provider)
    }

    public func unregister(id: String) {
        providers.removeAll { $0.id == id }
    }

    public func provider(
        supporting requiredCapabilities: Set<EdgeCapability>
    ) async -> (any EdgeModelProvider)? {
        for provider in providers {
            let capabilities = await provider.capabilities()
            if requiredCapabilities.isSubset(of: capabilities) {
                return provider
            }
        }

        return nil
    }
}
