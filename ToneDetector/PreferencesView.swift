import SwiftUI

struct PreferencesView: View {
    @State private var promptText: String = AppPreferences.getAgreeablePrompt()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agreeable Tone Prompt")
                .font(.headline)
            Text("Customize how the app evaluates tone. This prompt is sent to the on-device classifier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $promptText)
                .font(.body.monospaced())
                .padding(8)
                .frame(minHeight: 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .onChange(of: promptText) {
                    AppPreferences.setAgreeablePrompt(promptText)
                }

            HStack {
                Button("Reset to Default") {
                    AppPreferences.resetAgreeablePrompt()
                    promptText = AppPreferences.getAgreeablePrompt()
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 520)
    }
}

#Preview {
    PreferencesView()
}
