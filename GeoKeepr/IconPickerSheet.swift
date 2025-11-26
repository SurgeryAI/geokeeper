import SwiftUI

struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    let categorizedIcons: [String: [String]]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(categorizedIcons.keys.sorted(), id: \.self) { category in
                    Section(category) {
                        ForEach(categorizedIcons[category] ?? [], id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                dismiss()
                            } label: {
                                Label {
                                    Text(
                                        icon.replacingOccurrences(of: ".fill", with: "")
                                            .replacingOccurrences(of: ".", with: " ")
                                            .capitalized
                                    )
                                    .foregroundColor(.primary)
                                } icon: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .foregroundColor(.indigo)
                                        .frame(width: 30)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
