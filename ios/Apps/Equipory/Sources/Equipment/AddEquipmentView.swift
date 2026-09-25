import SwiftUI

struct AddEquipmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: EquipmentStore

    @State private var name = ""
    @State private var manufacturer = ""
    @State private var modelNumber = ""
    @State private var serialNumber = ""
    @State private var siteName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        // Camera/nameplate OCR is the next product slice.
                    } label: {
                        Label(
                            "Scan nameplate",
                            systemImage: "camera.viewfinder"
                        )
                    }
                }

                Section("Equipment") {
                    TextField("Equipment name", text: $name)
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model number", text: $modelNumber)
                    TextField("Serial number", text: $serialNumber)
                    TextField("Site / customer", text: $siteName)
                }
            }
            .navigationTitle("Add Equipment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(
                        name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
        }
    }

    private func save() {
        let asset = EquipmentAsset(
            id: UUID().uuidString,
            name: name,
            manufacturer: manufacturer,
            modelNumber: modelNumber,
            serialNumber: serialNumber,
            siteName: siteName,
            lastServiceAt: nil,
            sourceCount: 0,
            serviceNoteCount: 0,
            photoCount: 0,
            recentIssue: nil
        )

        store.add(asset)
        dismiss()
    }
}
