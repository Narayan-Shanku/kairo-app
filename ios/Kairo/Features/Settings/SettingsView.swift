import SwiftUI

struct SettingsView: View {
    @AppStorage("themeMode") private var themeModeRaw = ThemeMode.light.rawValue
    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @AppStorage("reminderHour") private var reminderHour = 19
    @Environment(\.dismiss) private var dismiss

    private let reminderHours = Array(6...23)
    private func hourLabel(_ h: Int) -> String {
        let suffix = h < 12 ? "AM" : "PM"
        let twelve = h % 12 == 0 ? 12 : h % 12
        return "\(twelve):00 \(suffix)"
    }

    private var mode: Binding<ThemeMode> {
        Binding(
            get: { ThemeMode(rawValue: themeModeRaw) ?? .system },
            set: { themeModeRaw = $0.rawValue }
        )
    }

    /// Live streak for the widget preview; falls back to a sample when there's no data yet.
    private var previewSnapshot: StreakSnapshot {
        let s = SharedStore.load()
        return s.lastActiveISO == nil ? .preview : s
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: mode) {
                        ForEach(ThemeMode.allCases) { m in
                            Label(m.label, systemImage: m.icon).tag(m)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Toggle("Daily check-in reminder", isOn: $remindersEnabled)
                    if remindersEnabled {
                        Picker("Remind me at", selection: $reminderHour) {
                            ForEach(reminderHours, id: \.self) { Text(hourLabel($0)).tag($0) }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("If you haven't checked in, Kairo sends an evening nudge so your streak doesn't break. All on-device.")
                }
                .onChange(of: remindersEnabled) { _, on in
                    Task {
                        if on { await NotificationService.requestAuthorization() }
                        NotificationService.refresh()
                    }
                }
                .onChange(of: reminderHour) { _, _ in NotificationService.refresh() }

                Section {
                    VStack(alignment: .center, spacing: 14) {
                        StreakWidgetPreview(snapshot: previewSnapshot, medium: true)
                        StreakWidgetPreview(snapshot: previewSnapshot, medium: false)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Home-screen widget")
                } footer: {
                    Text("Meet Kairo the sun — add the widget from your home screen: long-press → ➕ → search “Kairō”. Kairo beams when you're on a streak and dozes off if you drift.")
                }

                Section {
                    if AppConfig.standalone {
                        LabeledContent("Engine", value: "On-device")
                        LabeledContent("Storage", value: "On this iPhone")
                    } else {
                        LabeledContent("Backend", value: AppConfig.baseURL.absoluteString)
                    }
                    LabeledContent("Transcription",
                                   value: AppConfig.useOnDeviceTranscription ? "On-device" : "Server")
                    LabeledContent("Version", value: "0.2.0")
                } header: {
                    Text("About")
                } footer: {
                    if AppConfig.standalone {
                        Text("Kairō runs entirely on your device. Your memories never leave your iPhone.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
