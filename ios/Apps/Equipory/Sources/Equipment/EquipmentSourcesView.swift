import SwiftUI

struct EquipmentSourcesView: View {
    let asset: EquipmentAsset

    var body: some View {
        List {
            Label("Manuals", systemImage: "book.closed")
            Label("Service bulletins", systemImage: "doc.text")
            Label("Photos / labels", systemImage: "camera")
            Label("Technician notes", systemImage: "note.text")
        }
        .navigationTitle("Sources")
        .overlay {
            if asset.sourceCount == 0 {
                ContentUnavailableView(
                    "No sources yet",
                    systemImage: "doc.badge.plus",
                    description: Text(
                        "Add a manual, photo, bulletin, or note."
                    )
                )
            }
        }
    }
}
