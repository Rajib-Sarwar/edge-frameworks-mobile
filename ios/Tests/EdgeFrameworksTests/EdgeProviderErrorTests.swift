import XCTest
@testable import EdgeFrameworks

final class EdgeProviderErrorTests: XCTestCase {
    func testProviderUnavailablePreservesProviderIdentity() {
        let error = EdgeProviderError.providerUnavailable(
            providerID: "example.provider"
        )

        XCTAssertEqual(
            error,
            .providerUnavailable(providerID: "example.provider")
        )
    }

    func testUnsupportedCapabilityPreservesCapability() {
        let error = EdgeProviderError.unsupportedCapability(.vision)

        XCTAssertEqual(
            error,
            .unsupportedCapability(.vision)
        )
    }
}
