import SwiftUI

struct ServiceHistoryView: View {
    let asset: EquipmentAsset

    var body: some View {
        List {
            if let issue = asset.recentIssue {
                Section("Most Recent") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(issue)
                            .font(.headline)

                        Text(
                            "Service-note capture and AI closeout generation are the next implementation slice."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    // Service visit editor is next.
                } label: {
                    Label(
                        "Start service visit",
                        systemImage: "plus.circle"
                    )
                }
            }
        }
        .navigationTitle("Service History")
    }
}
