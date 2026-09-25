import SwiftUI

@main
struct EquiporyApp: App {
    @StateObject private var store = EquipmentStore.preview

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
