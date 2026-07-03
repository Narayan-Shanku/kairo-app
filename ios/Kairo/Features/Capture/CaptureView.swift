import SwiftUI

struct CaptureView: View {
    @State private var vm: CaptureViewModel
    @State private var text = ""
    @FocusState private var editorFocused: Bool

    init(env: AppEnvironment) {
        _vm = State(initialValue: CaptureViewModel(
            audio: env.audio, transcription: env.transcription, memories: env.memories))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Speak naturally for up to 5 minutes — what you learned, decided, or noticed today.")
                        .font(.subheadline).foregroundStyle(Theme.muted)

                    recorderCard

                    Divider().overlay(Theme.border)
                    Text("Or write it")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.muted)

                    TextEditor(text: $text)
                        .focused($editorFocused)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Theme.panel)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Theme.cream)

                    Button("Save entry") {
                        Task { await vm.saveText(text); if vm.errorMessage == nil { text = "" } }
                    }
                    .buttonStyle(GoldButton())
                    .disabled(vm.isBusy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let status = vm.statusMessage {
                        Text(status)
                            .font(.subheadline).foregroundStyle(Theme.creamDim)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.panel)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.domainColor("Health")))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    if let error = vm.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(Theme.danger)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .kairoBackground()
            .navigationTitle("Check-in")
            .toolbar {
                // TextEditor has no return-to-dismiss; give the keyboard a Done.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editorFocused = false }
                }
            }
        }
    }

    private var recorderCard: some View {
        VStack(spacing: 16) {
            Text(vm.elapsedLabel)
                .font(Theme.serif(34).monospacedDigit())
                .foregroundStyle(Theme.cream)

            Button {
                Task { await vm.toggleRecord() }
            } label: {
                Text(vm.isRecording ? "Stop" : "Record")
                    .font(.headline)
                    .foregroundStyle(vm.isRecording ? .white : Theme.onGold)
                    .padding(.horizontal, 34).padding(.vertical, 14)
                    .background(vm.isRecording ? Theme.danger : Theme.gold)
                    .clipShape(Capsule())
            }
            .disabled(vm.isBusy)

            Text(vm.isBusy ? "Transcribing…"
                           : "Tap to start. Tap again to stop & save. (\(vm.engineName))")
                .font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
