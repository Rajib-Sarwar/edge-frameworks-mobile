package io.github.rajibsarwar.edgeframeworks

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class EdgeProviderRouter(
    providers: List<EdgeModelProvider> = emptyList()
) {
    private val mutex = Mutex()
    private val providers = providers.toMutableList()

    suspend fun register(provider: EdgeModelProvider) {
        mutex.withLock {
            providers.removeAll { it.id == provider.id }
            providers.add(provider)
        }
    }

    suspend fun unregister(id: String) {
        mutex.withLock {
            providers.removeAll { it.id == id }
        }
    }

    suspend fun provider(
        requiredCapabilities: Set<EdgeCapability>
    ): EdgeModelProvider? {
        val snapshot = mutex.withLock { providers.toList() }

        for (provider in snapshot) {
            val capabilities = provider.capabilities()
            if (capabilities.containsAll(requiredCapabilities)) {
                return provider
            }
        }

        return null
    }
}
