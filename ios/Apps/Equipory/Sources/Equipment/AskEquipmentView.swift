import SwiftUI

struct AskEquipmentView: View {
    let asset: EquipmentAsset

    @State private var question = ""
    @State private var answer: String?

    var body: some View {
        VStack(spacing: 16) {
            if let answer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(answer)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )

                        Divider()

                        Label(
                            "Answer will include local source citations",
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Ask \(asset.name)",
                    systemImage: "sparkles",
                    description: Text(
                        "Answers will use only this equipment's local knowledge."
                    )
                )
            }

            HStack {
                TextField(
                    "Ask about this equipment",
                    text: $question,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)

                Button {
                    answer =
                        "RAG integration comes next. The question is scoped to \(asset.name)."
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(
                    question.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
        }
        .padding()
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
    }
}
