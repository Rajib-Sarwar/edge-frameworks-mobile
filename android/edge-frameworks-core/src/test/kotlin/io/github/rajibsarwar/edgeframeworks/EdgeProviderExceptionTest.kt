package io.github.rajibsarwar.edgeframeworks

import org.junit.Assert.assertEquals
import org.junit.Test

class EdgeProviderExceptionTest {
    @Test
    fun providerUnavailablePreservesProviderIdentity() {
        val error = EdgeProviderException.ProviderUnavailable(
            providerId = "example.provider"
        )

        assertEquals("example.provider", error.providerId)
    }

    @Test
    fun unsupportedCapabilityPreservesCapability() {
        val error = EdgeProviderException.UnsupportedCapability(
            EdgeCapability.VISION
        )

        assertEquals(EdgeCapability.VISION, error.capability)
    }
}
