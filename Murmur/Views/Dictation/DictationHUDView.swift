import SwiftUI

struct DictationHUDView: View {
    @Environment(DictationViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch viewModel.state {
            case .recording, .processing:
                FlowBarRecordingView()
            case .completed:
                FlowBarCompletedView()
            case .error(let message):
                FlowBarErrorView(message: message)
            default:
                FlowBarIdleView()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.state)
    }
}

// MARK: - Recording State (Full bar with waveform)

struct FlowBarRecordingView: View {
    @Environment(DictationViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 4) {
            // Live transcript preview
            if !viewModel.liveTranscript.isEmpty {
                Text(viewModel.liveTranscript.suffix(80))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .frame(maxWidth: 320, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            HStack(spacing: 10) {
                // Waveform bars
                FlowBarWaveform(amplitudes: viewModel.amplitudes)
                    .frame(width: 80, height: 24)

                // Session timer
                if let startTime = viewModel.sessionStartTime {
                    Text(startTime, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(minWidth: 30)
                }

                // Destination label
                Text(viewModel.destinationLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                // Stop button
                Button {
                    viewModel.commit()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop dictation")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, viewModel.liveTranscript.isEmpty ? 10 : 6)
            .padding(.bottom, viewModel.liveTranscript.isEmpty ? 0 : 4)
        }
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Murmur dictation bar — recording")
    }
}

// MARK: - Completed State (Brief confirmation with saved text)

struct FlowBarCompletedView: View {
    @Environment(DictationViewModel.self) private var viewModel

    private var displayText: String {
        if viewModel.showingRawText {
            return String(viewModel.rawText.prefix(60))
        } else {
            return String(viewModel.liveTranscript.prefix(60))
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isAIProcessing {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            }

            Text(displayText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            if viewModel.isAIProcessing {
                Text("Processing...")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text("Saved")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Raw/Edited toggle (visible when AI produced different output)
            if !viewModel.isAIProcessing && viewModel.rawText != viewModel.editedText && !viewModel.editedText.isEmpty {
                Button {
                    viewModel.showingRawText.toggle()
                } label: {
                    Image(systemName: viewModel.showingRawText ? "text.badge.checkmark" : "text.badge.minus")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.showingRawText ? "Show edited text" : "Show raw text")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
        .accessibilityLabel("Dictation saved: \(displayText)")
    }
}

// MARK: - Error State (Red-tinted pill with error message)

struct FlowBarErrorView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.red.opacity(0.25))
                .overlay(Capsule().strokeBorder(.red.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
        .accessibilityLabel("Dictation error: \(message)")
    }
}

// MARK: - Idle State (Always-visible small pill with mic icon)

struct FlowBarIdleView: View {
    @State private var isHovering = false
    @AppStorage("triggerKey") private var triggerKey = "fn"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var triggerHint: String {
        let key = TriggerKey(rawValue: triggerKey) ?? .fn
        return "Hold \(key.displayName)"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))

            if isHovering {
                Text(triggerHint)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, isHovering ? 12 : 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.black.opacity(isHovering ? 0.7 : 0.5))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel("Murmur — \(triggerHint) or press Command Shift Space to dictate")
    }
}

// MARK: - Waveform

struct FlowBarWaveform: View {
    var amplitudes: [Float]
    private let barCount = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                let amplitude = index < amplitudes.count
                    ? CGFloat(amplitudes[amplitudes.count - barCount + index])
                    : 0.05
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white)
                    .frame(width: 3, height: max(3, amplitude * 24))
                    .animation(.easeOut(duration: 0.08), value: amplitude)
            }
        }
    }
}

#Preview("Recording") {
    FlowBarRecordingView()
        .environment(DictationViewModel())
        .padding()
        .background(.gray)
}

#Preview("Completed") {
    FlowBarCompletedView()
        .environment(DictationViewModel())
        .padding()
        .background(.gray)
}

#Preview("Idle") {
    FlowBarIdleView()
        .padding()
        .background(.gray)
}

#Preview("Error") {
    FlowBarErrorView(message: "Speech recognition not authorized")
        .padding()
        .background(.gray)
}
