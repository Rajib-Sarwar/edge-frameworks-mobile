import CryptoKit
import Foundation

public enum EdgeContentFingerprint {
    public static func sha256(
        _ data: Data
    ) -> String {
        SHA256.hash(data: data)
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()
    }

    public static func sha256(
        _ text: String
    ) -> String {
        sha256(
            Data(text.utf8)
        )
    }
}
