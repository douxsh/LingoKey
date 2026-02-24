import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var apiKeyInput = ""
    @State private var selectedMode = KeyboardMode.enCorrection
    @State private var selectedAutoCorrectionLevel = AutoCorrectionLevel.conservative

    var body: some View {
        Form {
            Section("API Key") {
                SecureField("sk-...", text: $apiKeyInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Section("Default Keyboard Mode") {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(KeyboardMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Auto Correction") {
                Picker("Strength", selection: $selectedAutoCorrectionLevel) {
                    ForEach(AutoCorrectionLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Keyboard Status") {
                HStack {
                    Text("Full Access")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Button("Open Keyboard Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("LingoKey Settings")
        .onAppear {
            apiKeyInput = settings.apiKey
            selectedMode = KeyboardMode(rawValue: settings.defaultMode) ?? .enCorrection
            selectedAutoCorrectionLevel = AutoCorrectionLevel(rawValue: settings.autoCorrectionLevel) ?? .conservative
        }
        .onChange(of: apiKeyInput) { _, newValue in
            settings.apiKey = newValue
        }
        .onChange(of: selectedMode) { _, newValue in
            settings.defaultMode = newValue.rawValue
        }
        .onChange(of: selectedAutoCorrectionLevel) { _, newValue in
            settings.autoCorrectionLevel = newValue.rawValue
        }
    }
}
