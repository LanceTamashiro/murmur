import AppKit
import AVFoundation
import Foundation
import os.log
import SpeechEngine
import Models
import NoteStore
import PersonalDictionary

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

    private var speechEngine: (any SpeechEngineProtocol)?
    private var textInjectionService: TextInjectionService?
    private var noteStore: NoteStoreService?
    private var personalDictionary: PersonalDictionaryService?
    private var currentSessionID: UUID?
    private var sessionStartTime: Date?
    private var startupTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var amplitudeTask: Task<Void, Never>?

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
        personalDictionary: PersonalDictionaryService? = nil
    ) {
        self.speechEngine = speechEngine
        self.textInjectionService = textInjectionService
        self.noteStore = noteStore
        self.personalDictionary = personalDictionary
    }

    func toggle() {
        switch state {
        case .idle, .error:
            startDictation()
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
        logger.info("handleTranscriptionEvent: \(String(describing: event))")
        switch event {
        case .partial(let result):
            // Show accumulated finals + current partial as the live transcript
            let accumulated = finalizedSegments.joined()
            liveTranscript = accumulated + result.text
            let currentTranscript = liveTranscript
            logger.info("Partial transcript: \"\(currentTranscript.prefix(100))\"")

        case .final(let result):
            // Accumulate finalized segments — don't save yet, more text may follow.
            // The DictationTranscriber sends isFinal=true at sentence boundaries.
            finalizedSegments.append(result.text)
            lastLanguage = result.language
            liveTranscript = finalizedSegments.joined()
            let currentTranscript = liveTranscript
            logger.info("Final segment: \"\(result.text.prefix(100))\" (total so far: \"\(currentTranscript.prefix(100))\")")

        case .error(let error):
            logger.error("Transcription error: \(error)")
            showErrorThenReset(error.localizedDescription)

        case .sessionStarted(let sessionID):
            logger.info("Session started: \(sessionID)")
            finalizedSegments = []
            lastLanguage = "en-US"

        case .sessionEnded(_, let duration):
            let fullText = finalizedSegments.isEmpty ? liveTranscript : finalizedSegments.joined()
            logger.info("Session ended (duration=\(duration)s, segments=\(self.finalizedSegments.count), text=\"\(fullText.prefix(100))\")")
            saveDictationSession(duration: duration)

            if let earlyNoteID = earlyInjectionNoteID {
                // Early injection already happened — update the note if
                // analyzer finalization produced additional tail text.
                if fullText != earlyInjectionText,
                   !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let earlyCount = self.earlyInjectionText?.count ?? 0
                    logger.info("sessionEnded: updating note with tail text (\(fullText.count) vs \(earlyCount) chars)")
                    try? noteStore?.updateNote(earlyNoteID, bodyMarkdown: fullText)
                }
                earlyInjectionNoteID = nil
                earlyInjectionText = nil
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

    private func finalizeDictation(text: String, language: String, isEarlySnapshot: Bool = false) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.info("finalizeDictation: empty text, resetting")
            resetState()
            return
        }

        logger.info("finalizeDictation: \"\(text.prefix(100))\" (language=\(language), early=\(isEarlySnapshot))")

        Task {
            // ALWAYS save as a note — every dictation is recorded in history
            let noteID = saveAsNote(text: text, language: language)

            if isEarlySnapshot {
                // Track this so sessionEnded can update the note with tail text
                earlyInjectionNoteID = noteID
                earlyInjectionText = text
            }

            // Also try to inject into frontmost app's text field
            if let injectionService = textInjectionService {
                logger.info("finalizeDictation: attempting text injection...")
                let result = await injectionService.inject(text: text)
                logger.info("finalizeDictation: injection result = \(String(describing: result))")

                if case .success(strategy: .clipboardCopy) = result {
                    // Text was copied to clipboard but not auto-pasted (AX + CGEvent both failed).
                    // Show a brief notification so the user knows to paste manually.
                    liveTranscript = "Copied to clipboard — press ⌘V to paste"
                    state = .completed
                    try? await Task.sleep(for: .seconds(3.0))
                    resetState()
                    return
                }
            }

            state = .completed
            liveTranscript = text

            // Auto-dismiss after completion
            try? await Task.sleep(for: .seconds(2.0))
            resetState()
        }
    }

    @discardableResult
    private func saveAsNote(text: String, language: String) -> UUID? {
        guard let noteStore else {
            logger.error("saveAsNote: noteStore is nil!")
            return nil
        }
        logger.info("saveAsNote: saving note \"\(text.prefix(50))\"")
        do {
            let note = try noteStore.createNote(
                bodyMarkdown: text,
                sourceApp: textInjectionService?.appContextDetector.currentAppContext?.bundleIdentifier,
                language: language
            )
            logger.info("saveAsNote: note saved successfully (id=\(note.id))")
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
        startupTask?.cancel()
        startupTask = nil
        eventTask?.cancel()
        amplitudeTask?.cancel()
        eventTask = nil
        amplitudeTask = nil
        currentSessionID = nil
        sessionStartTime = nil
        finalizedSegments = []
        earlyInjectionNoteID = nil
        earlyInjectionText = nil
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
