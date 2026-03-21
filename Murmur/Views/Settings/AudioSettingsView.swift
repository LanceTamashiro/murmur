import SwiftUI
import SpeechEngine

struct AudioSettingsView: View {
    @AppStorage("selectedMicrophoneID") private var selectedMicrophoneID = ""
    @AppStorage("whisperMode") private var whisperMode = false
    @State private var devices: [AudioInputDevice] = []
    @State private var testingLevel = false
    @State private var currentLevel: Float = 0

    private let micManager = MicrophoneManager()

    var body: some View {
        Form {
            Section("Microphone") {
                Picker("Input Device", selection: $selectedMicrophoneID) {
                    Text("System Default").tag("")
                    ForEach(devices) { device in
                        HStack {
                            Text(device.name)
                            if device.isDefault {
                                Text("(Default)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(device.id)
                    }
                }

                if !devices.isEmpty {
                    HStack(spacing: 8) {
                        Text("Level")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.quaternary)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(levelColor)
                                    .frame(width: geo.size.width * CGFloat(min(currentLevel * 3, 1.0)))
                                    .animation(.linear(duration: 0.05), value: currentLevel)
                            }
                        }
                        .frame(height: 8)
                    }
                    .opacity(testingLevel ? 1 : 0.4)

                    Button(testingLevel ? "Stop Test" : "Test Microphone") {
                        testingLevel.toggle()
                        if testingLevel {
                            startLevelTest()
                        } else {
                            stopLevelTest()
                        }
                    }
                    .controlSize(.small)
                }
            }

            Section("Voice") {
                Toggle("Whisper Mode", isOn: $whisperMode)
                Text("Boosts microphone gain for quiet speech. Use when speaking softly or in a noisy environment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { refreshDevices() }
        .onDisappear { stopLevelTest() }
    }

    private var levelColor: Color {
        if currentLevel * 3 > 0.8 {
            return .red
        } else if currentLevel * 3 > 0.5 {
            return .yellow
        }
        return .green
    }

    @State private var levelTask: Task<Void, Never>?

    private func refreshDevices() {
        devices = micManager.availableInputDevices
    }

    private func startLevelTest() {
        levelTask = Task {
            // Simple level monitoring using AVAudioEngine
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let frameCount = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameCount {
                    sum += abs(channelData[i])
                }
                let average = sum / Float(max(frameCount, 1))
                Task { @MainActor in
                    currentLevel = average
                }
            }

            do {
                try engine.start()
                // Keep running until cancelled
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(0.1))
                }
            } catch {
                // Silently fail — mic test is optional
            }

            inputNode.removeTap(onBus: 0)
            engine.stop()
        }
    }

    private func stopLevelTest() {
        testingLevel = false
        levelTask?.cancel()
        levelTask = nil
        currentLevel = 0
    }
}

import AVFoundation
