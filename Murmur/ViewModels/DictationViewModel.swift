import AppKit
import AVFoundation
import Foundation
import os.log
import SpeechEngine
import Models
import NoteStore
import PersonalDictionary
import AIEditor

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "DictationViewModel")

@Observable
@MainActor
final class DictationViewModel {
    enum State: Equatable {
        case idle
        case recording
        case processing
        case completed
        case error(String)
    }

    var state: State = .idle
    var liveTranscript: String = ""
    var amplitudes: [Float] = Array(repeating: 0.05, count: 20)
    var destinationLabel: String = "New Note"

    /// The raw (pre-AI) text from the last dictation.
    var rawText: String = ""
    /// The AI-edited text from the last dictation (same as rawText if AI is disabled/unavailable).
    var editedText: String = ""
    /// Whether AI processing is currently in progress.
    var isAIProcessing: Bool = false
    /// Whether the HUD is showing raw text instead of edited text.
    var showingRawText: Bool = false

    private var speechEngine: (any SpeechEngineProtocol)?
    private var textInjectionService: TextInjectionService?
    private var noteStore: NoteStoreService?
    private var personalDictionary: PersonalDictionaryService?
    private var aiPipeline: EditingPipeline?
    private var currentSessionID: UUID?
    private(set) var sessionStartTime: Date?
    private var startupTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var amplitudeTask: Task<Void, Never>?
    private var maxDurationTask: Task<Void, Never>?
    private var finalizationTask: Task<Void, Never>?
    private var sessionHasEnded = false
    private let recoveryManager = SessionRecoveryManager()

    /// Tracks early injection: when the user releases the globe key, we inject
    /// the already-accumulated text immediately (without waiting for analyzer
    /// finalization). If finalization later produces additional tail text, we
    /// update the saved note.
    private var earlyInjectionNoteID: UUID?
    private var earlyInjectionText: String?

    func configure(
        speechEngine: any SpeechEngineProtocol,
        textInjectionService: TextInjectionService,
        noteStore: NoteStoreService,
        personalDictionary: PersonalDictionaryService? = nil,
        aiPipeline: EditingPipeline? = nil
    ) {
        self.speechEngine = speechEngine
        self.textInjectionService = textInjectionService
        self.noteStore = noteStore
        self.personalDictionary = personalDictionary
        self.aiPipeline = aiPipeline
    }

    func toggle() {
        switch state {
        case .idle, .error:
            startDictation()
            startMaxDurationTimer()
        case .recording:
            stopDictation()
        default:
            break
        }
    }

    func cancel() {
        Task {
            await speechEngine?.cancelSession()
            resetState()
        }
    }

    func commit() {
        stopDictation()
    }

    /// Request speech + microphone authorization early (called from AppDelegate.setup)
    func requestAuthorizationIfNeeded() {
        guard let speechEngine else { return }
        Task {
            // Request microphone permission first — this MUST be granted before
            // we can safely access AVAudioEngine.inputNode (otherwise CoreAudio -10877)
            let micGranted = await AVAudioApplication.requestRecordPermission()
            if !micGranted {
                showErrorThenReset("Microphone access denied — enable in System Settings > Privacy > Microphone")
                return
            }

            // Then request speech recognition authorization
            let status = await speechEngine.requestAuthorization()
            if status == .denied {
                showErrorThenReset("Speech recognition denied — enable in System Settings > Privacy")
            } else if status == .restricted {
                showErrorThenReset("Speech recognition restricted on this device")
            }
        }
    }

    /// Start recording (called by push-to-talk on Fn key down)
    func startDictation() {
        guard let speechEngine else {
            logger.error("startDictation: speechEngine is nil — was configure() called?")
            return
        }
        logger.info("startDictation: beginning...")

        state = .recording
        liveTranscript = ""
        finalizedSegments = []
        sessionHasEnded = false
        lastLanguage = "en-US"
        amplitudes = Array(repeating: 0.05, count: 20)
        sessionStartTime = Date()
        postAccessibilityAnnouncement("Dictation started")

        // Update destination based on frontmost app
        if let context = textInjectionService?.appContextDetector.currentAppContext {
            destinationLabel = context.displayName
        } else {
            destinationLabel = "New Note"
        }

        startupTask = Task {
            do {
                // Ensure microphone permission before touching audio hardware
                let currentMicPerm = AVAudioApplication.shared.recordPermission
                logger.info("startDictation: mic permission = \(String(describing: currentMicPerm))")
                if currentMicPerm != .granted {
                    logger.info("startDictation: requesting mic permission...")
                    let granted = await AVAudioApplication.requestRecordPermission()
                    logger.info("startDictation: mic permission granted = \(granted)")
                    guard granted else {
                        showErrorThenReset("Microphone access denied — enable in System Settings > Privacy > Microphone")
                        return
                    }
                }

                // Bail out if stop was called while awaiting mic permission
                guard state == .recording else {
                    logger.info("startDictation: state changed during mic permission — aborting")
                    return
                }

                // Ensure speech recognition authorization before starting
                logger.info("startDictation: requesting speech auth...")
                let authStatus = await speechEngine.requestAuthorization()
                logger.info("startDictation: speech auth = \(String(describing: authStatus))")
                guard authStatus == .authorized else {
                    switch authStatus {
                    case .denied:
                        showErrorThenReset("Speech recognition denied — enable in System Settings > Privacy")
                    case .restricted:
                        showErrorThenReset("Speech recognition restricted on this device")
                    default:
                        showErrorThenReset("Speech recognition not available")
                    }
                    return
                }

                // Bail out if stop was called while awaiting speech auth
                guard state == .recording else {
                    logger.info("startDictation: state changed during speech auth — aborting")
                    return
                }

                // Apply whisper mode setting before starting session
                if let engine = speechEngine as? DictationTranscriberEngine {
                    engine.whisperModeEnabled = UserDefaults.standard.bool(forKey: "whisperMode")
                }

                let vocabulary = (try? personalDictionary?.vocabularyWords()) ?? []
                logger.info("startDictation: starting speech session...")
                let sessionID = try await speechEngine.startSession(locale: nil, customVocabulary: vocabulary)

                // Bail out if stop was called while starting the session —
                // clean up the orphan session that just started
                guard state == .recording else {
                    logger.info("startDictation: state changed during startSession — stopping orphan session")
                    await speechEngine.stopSession()
                    return
                }

                currentSessionID = sessionID
                logger.info("startDictation: session started successfully (id=\(sessionID))")

                // Start periodic recovery saves
                let sourceApp = self.textInjectionService?.appContextDetector.currentAppContext?.bundleIdentifier
                self.recoveryManager.startPeriodicSave(
                    textProvider: { [weak self] in
                        guard let self else { return nil }
                        let text = self.finalizedSegments.isEmpty ? self.liveTranscript : self.finalizedSegments.joined()
                        return (text: text, language: self.lastLanguage, sourceApp: sourceApp)
                    },
                    startTime: self.sessionStartTime ?? Date()
                )

                // Consume transcription events
                eventTask = Task {
                    for await event in speechEngine.transcriptionEvents {
                        handleTranscriptionEvent(event)
                    }
                }

                // Consume amplitude
                amplitudeTask = Task {
                    for await amplitude in speechEngine.amplitudeStream {
                        pushAmplitude(amplitude)
                    }
                }
            } catch is CancellationError {
                // Task was cancelled by stopDictation() — stopDictation already
                // called resetState(), so just bail silently.
                logger.info("startDictation: startup task cancelled")
            } catch {
                logger.error("startDictation: FAILED — \(error)")
                showErrorThenReset(error.localizedDescription)
            }
            startupTask = nil
        }
    }

    /// Stop recording and inject text (called by push-to-talk on Fn key up)
    func stopAndInject() {
        stopDictation()
    }

    private func stopDictation() {
        guard let speechEngine, state == .recording else { return }
        state = .processing

        if currentSessionID != nil {
            // Capture the text that's already visible in the pill — don't wait
            // for analyzer finalization, which only catches tail audio after the
            // last sentence boundary.
            let accumulated = finalizedSegments.joined()
            let partial: String
            if !accumulated.isEmpty, liveTranscript.hasPrefix(accumulated) {
                partial = String(liveTranscript.dropFirst(accumulated.count))
            } else if finalizedSegments.isEmpty {
                partial = liveTranscript
            } else {
                partial = ""
            }
            let snapshotText = accumulated + partial

            if !snapshotText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Begin injection immediately with the snapshot text
                logger.info("stopDictation: early injection with \(snapshotText.count) chars")
                finalizeDictation(text: snapshotText, language: lastLanguage, isEarlySnapshot: true)
            }

            // Stop session in background — sessionEnded will update the note
            // with any tail text from finalization
            Task {
                await speechEngine.stopSession()
            }

            // Safety net: if state hasn't returned to .idle within 15 seconds,
            // force reset. Catches unforeseen edge cases where both the
            // finalizationTask and .sessionEnded fail to reset state.
            Task {
                try? await Task.sleep(for: .seconds(15))
                if state != .idle {
                    logger.warning("stopDictation: safety timeout — forcing reset from \(String(describing: self.state))")
                    resetState()
                }
            }
        } else {
            // Session hasn't started yet — the startup Task is still in its async
            // preamble (e.g., waiting for mic permission). Cancel it and reset.
            // The state guards in startDictation will also see state != .recording.
            startupTask?.cancel()
            startupTask = nil
            logger.info("stopDictation: cancelled startup (no session yet)")
            resetState()
        }
    }

    /// Accumulated finalized text segments. The DictationTranscriber produces
    /// intermediate `isFinal=true` results at sentence boundaries — we collect
    /// them all and only save/inject when the session actually ends.
    private var finalizedSegments: [String] = []
    private var lastLanguage: String = "en-US"

    private func handleTranscriptionEvent(_ event: TranscriptionEvent) {
        switch event {
        case .partial(let result):
            // Show accumulated finals + current partial as the live transcript
            let accumulated = finalizedSegments.joined()
            liveTranscript = accumulated + result.text
            logger.debug("Partial transcript: \(self.liveTranscript.count) chars")

        case .final(let result):
            // Accumulate finalized segments — don't save yet, more text may follow.
            // The DictationTranscriber sends isFinal=true at sentence boundaries.
            finalizedSegments.append(result.text)
            lastLanguage = result.language
            liveTranscript = finalizedSegments.joined()
            logger.info("Final segment received (segments=\(self.finalizedSegments.count), total=\(self.liveTranscript.count) chars)")

        case .error(let error):
            logger.error("Transcription error: \(error)")
            showErrorThenReset(error.localizedDescription)

        case .sessionStarted(let sessionID):
            logger.info("Session started: \(sessionID)")
            finalizedSegments = []
            lastLanguage = "en-US"

        case .sessionEnded(_, let duration):
            let fullText = finalizedSegments.isEmpty ? liveTranscript : finalizedSegments.joined()
            logger.info("Session ended (duration=\(duration)s, segments=\(self.finalizedSegments.count), chars=\(fullText.count))")
            saveDictationSession(duration: duration)
            sessionHasEnded = true

            if let earlyNoteID = earlyInjectionNoteID {
                // Early injection already happened — update the note if
                // analyzer finalization produced additional tail text.
                if fullText != earlyInjectionText,
                   !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let earlyCount = self.earlyInjectionText?.count ?? 0
                    logger.info("sessionEnded: updating note with tail text (\(fullText.count) vs \(earlyCount) chars)")
                    try? noteStore?.updateNote(earlyNoteID, bodyMarkdown: fullText)
                }
                // Show completed state briefly, then reset to idle.
                state = .completed
                liveTranscript = fullText.isEmpty ? (earlyInjectionText ?? "") : fullText
                Task {
                    try? await Task.sleep(for: .seconds(2.0))
                    resetState()
                }
            } else {
                // No early injection (text was empty at stop time) — inject normally
                if !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalizeDictation(text: fullText, language: lastLanguage)
                } else {
                    logger.warning("Session ended with no text — nothing to save")
                    resetState()
                }
            }
        }
    }

    private var aiEditingEnabled: Bool {
        UserDefaults.standard.object(forKey: "aiEditingEnabled") as? Bool ?? true
    }

    private func finalizeDictation(text: String, language: String, isEarlySnapshot: Bool = false) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.info("finalizeDictation: empty text, resetting")
            resetState()
            return
        }

        logger.info("finalizeDictation: \(text.count) chars (language=\(language), early=\(isEarlySnapshot))")

        // Track raw text
        rawText = text
        editedText = text

        // Save note synchronously (SwiftData, on MainActor) — ensures
        // earlyInjectionNoteID is set BEFORE any async work, eliminating the
        // race with .sessionEnded.
        let noteID = saveAsNote(text: text, language: language)

        if isEarlySnapshot {
            earlyInjectionNoteID = noteID
            earlyInjectionText = text
        }

        finalizationTask = Task {
            if isEarlySnapshot {
                // HOLD MODE: inject raw text immediately, run AI in background
                await injectText(text)
                state = .completed
                liveTranscript = text

                // Run AI in background if enabled
                if aiEditingEnabled, let pipeline = aiPipeline {
                    isAIProcessing = true
                    let request = EditingRequest(text: text, language: language)
                    let result = await pipeline.process(request)
                    isAIProcessing = false

                    if result.wasModified {
                        editedText = result.processedText
                        liveTranscript = result.processedText
                        logger.info("finalizeDictation: AI edited text (\(text.count) → \(result.processedText.count) chars)")
                        // Update note with AI-edited text
                        if let nid = noteID {
                            try? noteStore?.updateNote(nid, bodyMarkdown: result.processedText)
                        }
                    }
                }
            } else {
                // TOGGLE MODE: run AI pipeline before injection
                var textToInject = text

                if aiEditingEnabled, let pipeline = aiPipeline {
                    isAIProcessing = true
                    let request = EditingRequest(text: text, language: language)
                    let result = await pipeline.process(request)
                    isAIProcessing = false

                    if result.wasModified {
                        textToInject = result.processedText
                        editedText = result.processedText
                        logger.info("finalizeDictation: AI edited text (\(text.count) → \(result.processedText.count) chars)")
                        // Update note with AI-edited text
                        if let nid = noteID {
                            try? noteStore?.updateNote(nid, bodyMarkdown: result.processedText)
                        }
                    }
                }

                await injectText(textToInject)

                state = .completed
                liveTranscript = textToInject
                try? await Task.sleep(for: .seconds(2.0))
                resetState()
            }
        }
    }

    /// Inject text into the frontmost app. Returns true if injection required clipboard-only fallback.
    private func injectText(_ text: String) async -> Bool {
        guard let injectionService = textInjectionService else { return false }
        logger.info("finalizeDictation: attempting text injection...")
        let result = await injectionService.inject(text: text)
        logger.info("finalizeDictation: injection result = \(String(describing: result))")

        if case .success(strategy: .clipboardCopy) = result {
            liveTranscript = "Copied to clipboard — press ⌘V to paste"
            state = .completed
            try? await Task.sleep(for: .seconds(3.0))
            return true
        }
        return false
    }

    @discardableResult
    private func saveAsNote(text: String, language: String) -> UUID? {
        guard let noteStore else {
            logger.error("saveAsNote: noteStore is nil!")
            return nil
        }
        logger.info("saveAsNote: saving note (\(text.count) chars)")
        do {
            let note = try noteStore.createNote(
                bodyMarkdown: text,
                sourceApp: textInjectionService?.appContextDetector.currentAppContext?.bundleIdentifier,
                language: language
            )
            logger.info("saveAsNote: note saved successfully (id=\(note.id))")
            recoveryManager.clearRecovery()
            return note.id
        } catch {
            logger.error("saveAsNote: FAILED — \(error)")
            return nil
        }
    }

    private func saveDictationSession(duration: TimeInterval) {
        // DictationSession creation would go here
        // Deferred to full integration pass
    }

    private func startMaxDurationTimer() {
        maxDurationTask?.cancel()
        let maxSeconds = UserDefaults.standard.object(forKey: "toggleMaxDuration") as? Int ?? 300
        guard maxSeconds > 0 else { return } // 0 = no limit
        logger.info("startMaxDurationTimer: will auto-stop after \(maxSeconds)s")
        maxDurationTask = Task {
            try? await Task.sleep(for: .seconds(maxSeconds))
            guard !Task.isCancelled, state == .recording else { return }
            logger.info("startMaxDurationTimer: max duration reached — auto-stopping")
            stopDictation()
        }
    }

    private func pushAmplitude(_ value: Float) {
        amplitudes.removeFirst()
        amplitudes.append(min(value * 3, 1.0)) // Scale for visual impact
    }

    private func showErrorThenReset(_ message: String) {
        state = .error(message)
        Task {
            try? await Task.sleep(for: .seconds(3))
            if case .error = state {
                resetState()
            }
        }
    }

    private func resetState() {
        state = .idle
        recoveryManager.stopPeriodicSave()
        startupTask?.cancel()
        startupTask = nil
        eventTask?.cancel()
        amplitudeTask?.cancel()
        maxDurationTask?.cancel()
        finalizationTask?.cancel()
        eventTask = nil
        amplitudeTask = nil
        maxDurationTask = nil
        finalizationTask = nil
        sessionHasEnded = false
        currentSessionID = nil
        sessionStartTime = nil
        finalizedSegments = []
        earlyInjectionNoteID = nil
        earlyInjectionText = nil
        rawText = ""
        editedText = ""
        isAIProcessing = false
        showingRawText = false
        postAccessibilityAnnouncement("Dictation ended")
    }

    private func postAccessibilityAnnouncement(_ message: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high]
        )
    }
}
