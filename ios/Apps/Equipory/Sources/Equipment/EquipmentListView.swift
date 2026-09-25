import SwiftUI

struct EquipmentListView: View {
    @EnvironmentObject private var store: EquipmentStore

    @State private var searchText = ""
    @State private var isAddingEquipment = false

    private var filteredEquipment: [EquipmentAsset] {
        guard !searchText.isEmpty else {
            return store.equipment
        }

        return store.equipment.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.siteName.localizedCaseInsensitiveContains(searchText) ||
            $0.modelNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredEquipment) { asset in
                NavigationLink {
                    EquipmentWorkspaceView(asset: asset)
                } label: {
                    EquipmentRow(asset: asset)
                }
            }
            .navigationTitle("Equipment")
            .searchable(
                text: $searchText,
                prompt: "Search equipment, site, model"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingEquipment = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add equipment")
                }
            }
            .sheet(isPresented: $isAddingEquipment) {
                AddEquipmentView()
            }
        }
    }
}

private struct EquipmentRow: View {
    let asset: EquipmentAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(asset.name)
                    .font(.headline)

                Spacer()

                Image(systemName: "checkmark.shield")
                    .foregroundStyle(.secondary)
            }

            Text(asset.siteName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(asset.manufacturer) · \(asset.modelNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let recentIssue = asset.recentIssue {
                Label(
                    recentIssue,
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
