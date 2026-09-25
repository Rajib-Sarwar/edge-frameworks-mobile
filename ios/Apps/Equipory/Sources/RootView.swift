import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            EquipmentListView()
                .tabItem {
                    Label("Equipment", systemImage: "wrench.and.screwdriver")
                }

            NavigationStack {
                Text("Recent service activity")
                    .navigationTitle("Service")
            }
            .tabItem {
                Label("Service", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                Text("Local AI and privacy settings")
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
