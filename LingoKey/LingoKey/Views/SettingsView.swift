import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var apiKeyInput = ""
    @State private var selectedMode = KeyboardMode.enCorrection

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
        }
        .onChange(of: apiKeyInput) { _, newValue in
            settings.apiKey = newValue
        }
        .onChange(of: selectedMode) { _, newValue in
            settings.defaultMode = newValue.rawValue
        }
    }
}
