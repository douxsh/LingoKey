import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var apiKeyInput = ""
    @State private var selectedMode = KeyboardMode.enCorrection
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            // Page 1: Welcome
            welcomePage.tag(0)
            // Page 2: Enable keyboard guide
            enableKeyboardPage.tag(1)
            // Page 3: API Key + Mode
            setupPage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .navigationTitle("LingoKey Setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "keyboard")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to LingoKey")
                .font(.largeTitle.bold())
            Text("AI-powered multilingual keyboard\nfor English & Korean")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            nextButton
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 50)
    }

    private var enableKeyboardPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "gear")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Enable LingoKey Keyboard")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Open Settings app")
                instructionRow(number: "2", text: "General > Keyboard > Keyboards")
                instructionRow(number: "3", text: "Add New Keyboard > LingoKey")
                instructionRow(number: "4", text: "Tap LingoKey > Allow Full Access")
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)

            Spacer()
            nextButton
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 50)
    }

    private var setupPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Configuration")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI API Key")
                    .font(.headline)
                SecureField("sk-...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Default Mode")
                    .font(.headline)
                Picker("Mode", selection: $selectedMode) {
                    ForEach(KeyboardMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Spacer()

            Button {
                settings.apiKey = apiKeyInput
                settings.defaultMode = selectedMode.rawValue
                settings.onboardingCompleted = true
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyInput.isEmpty)
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 50)
    }

    // MARK: - Helpers

    private var nextButton: some View {
        Button {
            withAnimation { currentPage += 1 }
        } label: {
            Text("Next")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
            Text(text)
                .font(.body)
        }
    }
}
