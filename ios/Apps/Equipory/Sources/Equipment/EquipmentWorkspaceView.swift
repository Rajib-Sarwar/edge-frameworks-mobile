import SwiftUI

struct EquipmentWorkspaceView: View {
    let asset: EquipmentAsset

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(asset.name)
                        .font(.title2.bold())

                    Text(asset.siteName)
                        .foregroundStyle(.secondary)

                    Text("\(asset.manufacturer) · \(asset.modelNumber)")
                        .font(.subheadline)

                    Text("Serial: \(asset.serialNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                NavigationLink {
                    AskEquipmentView(asset: asset)
                } label: {
                    Label("Ask this equipment", systemImage: "sparkles")
                }
            }

            Section("Knowledge") {
                NavigationLink {
                    EquipmentSourcesView(asset: asset)
                } label: {
                    Label(
                        "\(asset.sourceCount) sources",
                        systemImage: "doc.text"
                    )
                }

                NavigationLink {
                    ServiceHistoryView(asset: asset)
                } label: {
                    Label(
                        "\(asset.serviceNoteCount) service notes",
                        systemImage: "clock.arrow.circlepath"
                    )
                }

                Label(
                    "\(asset.photoCount) photos",
                    systemImage: "photo"
                )
            }

            if let recentIssue = asset.recentIssue {
                Section("Recent Issue") {
                    Text(recentIssue)
                }
            }
        }
        .navigationTitle("Workspace")
        .navigationBarTitleDisplayMode(.inline)
    }
}
