import Combine
import Foundation

@MainActor
final class EquipmentStore: ObservableObject {
    @Published private(set) var equipment: [EquipmentAsset]

    init(equipment: [EquipmentAsset] = []) {
        self.equipment = equipment
    }

    func add(_ asset: EquipmentAsset) {
        equipment.insert(asset, at: 0)
    }

    static let preview = EquipmentStore(
        equipment: [
            EquipmentAsset(
                id: "rtu-12",
                name: "Carrier RTU #12",
                manufacturer: "Carrier",
                modelNumber: "48TCED14A2A5A0A0",
                serialNumber: "1625V12345",
                siteName: "North Plaza",
                lastServiceAt: Date(),
                sourceCount: 3,
                serviceNoteCount: 14,
                photoCount: 27,
                recentIssue: "High-pressure lockout"
            ),
            EquipmentAsset(
                id: "boiler-a",
                name: "Boiler A",
                manufacturer: "Lochinvar",
                modelNumber: "KBN501",
                serialNumber: "LCH-883214",
                siteName: "Riverside Office",
                lastServiceAt: nil,
                sourceCount: 1,
                serviceNoteCount: 2,
                photoCount: 5,
                recentIssue: nil
            )
        ]
    )
}
