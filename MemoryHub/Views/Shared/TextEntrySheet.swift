import SwiftUI

struct TextEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let placeholder: String
    let confirmTitle: String
    let onConfirm: (String) -> Void

    @State private var text: String

    init(
        title: String,
        placeholder: String,
        initialText: String = "",
        confirmTitle: String,
        onConfirm: @escaping (String) -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(MHTheme.fieldBackground, in: RoundedRectangle(cornerRadius: MHTheme.controlRadius))
                Spacer()
            }
            .padding(MHTheme.pagePadding)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        onConfirm(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .memoryHubPage()
        }
        .presentationDetents([.height(230)])
    }
}

