import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ProviderSettingsView: View {
    @State private var openAIKey: String = ""
    @State private var claudeKey: String = ""
    @AppStorage("openaiModel") private var openAIModel = "gpt-4o"
    @AppStorage("claudeModel") private var claudeModel = "claude-sonnet-4-6-20250514"

    @State private var openAIStatus: ProviderStatus = .unconfigured
    @State private var claudeStatus: ProviderStatus = .unconfigured
    @State private var appleIntelligenceAvailable = false

    @State private var testingOpenAI = false
    @State private var testingClaude = false

    private let keychain = KeychainService()

    enum ProviderStatus: Equatable {
        case unconfigured, configured, testing, error(String)

        var label: String {
            switch self {
            case .unconfigured: return "Not Configured"
            case .configured: return "Configured"
            case .testing: return "Testing..."
            case .error(let msg): return "Error: \(msg)"
            }
        }

        var color: Color {
            switch self {
            case .unconfigured: return .secondary
            case .configured: return .green
            case .testing: return .orange
            case .error: return .red
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // OpenAI
            DisclosureGroup {
                SecureField("API Key", text: $openAIKey)
                    .onSubmit { saveOpenAIKey() }
                    .onChange(of: openAIKey) { _, _ in
                        openAIStatus = openAIKey.isEmpty ? .unconfigured : .configured
                    }

                Picker("Model", selection: $openAIModel) {
                    Text("GPT-4o").tag("gpt-4o")
                    Text("GPT-4o Mini").tag("gpt-4o-mini")
                    Text("GPT-4.1").tag("gpt-4.1")
                    Text("GPT-4.1 Mini").tag("gpt-4.1-mini")
                }

                HStack {
                    Button("Save Key") { saveOpenAIKey() }
                        .disabled(openAIKey.isEmpty)
                    Button("Remove") { removeOpenAIKey() }
                        .disabled(openAIStatus == .unconfigured)
                }
            } label: {
                HStack {
                    Text("OpenAI")
                        .fontWeight(.medium)
                    Spacer()
                    statusBadge(openAIStatus)
                }
            }

            // Claude
            DisclosureGroup {
                SecureField("API Key", text: $claudeKey)
                    .onSubmit { saveClaudeKey() }
                    .onChange(of: claudeKey) { _, _ in
                        claudeStatus = claudeKey.isEmpty ? .unconfigured : .configured
                    }

                Picker("Model", selection: $claudeModel) {
                    Text("Claude Sonnet 4.6").tag("claude-sonnet-4-6-20250514")
                    Text("Claude Haiku 4.5").tag("claude-haiku-4-5-20251001")
                }

                HStack {
                    Button("Save Key") { saveClaudeKey() }
                        .disabled(claudeKey.isEmpty)
                    Button("Remove") { removeClaudeKey() }
                        .disabled(claudeStatus == .unconfigured)
                }
            } label: {
                HStack {
                    Text("Claude")
                        .fontWeight(.medium)
                    Spacer()
                    statusBadge(claudeStatus)
                }
            }

            // Apple Intelligence
            HStack {
                Text("Apple Intelligence")
                    .fontWeight(.medium)
                Spacer()
                if appleIntelligenceAvailable {
                    statusBadge(.configured)
                } else {
                    statusBadge(.unconfigured)
                }
            }
            Text("On-device processing. No API key needed. Requires Apple Silicon Mac with macOS 26+.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .onAppear {
            loadProviderStatus()
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: ProviderStatus) -> some View {
        Text(status.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }

    private func loadProviderStatus() {
        if let key = keychain.load(for: "openai"), !key.isEmpty {
            openAIKey = key
            openAIStatus = .configured
        }
        if let key = keychain.load(for: "claude"), !key.isEmpty {
            claudeKey = key
            claudeStatus = .configured
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            appleIntelligenceAvailable = SystemLanguageModel.default.isAvailable
        }
        #endif
    }

    private func saveOpenAIKey() {
        guard !openAIKey.isEmpty else { return }
        try? keychain.save(apiKey: openAIKey, for: "openai")
        openAIStatus = .configured
    }

    private func removeOpenAIKey() {
        keychain.delete(for: "openai")
        openAIKey = ""
        openAIStatus = .unconfigured
    }

    private func saveClaudeKey() {
        guard !claudeKey.isEmpty else { return }
        try? keychain.save(apiKey: claudeKey, for: "claude")
        claudeStatus = .configured
    }

    private func removeClaudeKey() {
        keychain.delete(for: "claude")
        claudeKey = ""
        claudeStatus = .unconfigured
    }
}
