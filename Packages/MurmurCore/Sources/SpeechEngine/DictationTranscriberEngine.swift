@preconcurrency import AVFoundation
import Foundation
import os.log
import Speech

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "SpeechEngine")

public final class DictationTranscriberEngine: SpeechEngineProtocol, @unchecked Sendable {
    // IMPORTANT: audioEngine must be lazy — creating AVAudioEngine() eagerly
    // initializes CoreAudio hardware, which throws -10877 if mic permission
    // hasn't been granted yet. By making it lazy, it's only created when
    // startSession() is called, after mic permission is confirmed.
    private lazy var audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var detector: SpeechDetector?
    private var currentSessionID: UUID?
    private var sessionStartTime: Date?
    private var transcriptionTask: Task<Void, Never>?
    private var detectionTask: Task<Void, Never>?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?

    /// When true, applies +12dB gain boost for quiet/whisper speech.
    public var whisperModeEnabled: Bool = false
    /// +12dB ≈ 4x amplitude multiplier
    private let whisperGainMultiplier: Float = 3.981 // pow(10, 12.0/20.0)

    private var eventContinuation: AsyncStream<TranscriptionEvent>.Continuation?
    private var amplitudeContinuation: AsyncStream<Float>.Continuation?

    // IMPORTANT: These are recreated per session. AsyncStream only supports a single
    // iterator — once the first `for await` is cancelled, a second iteration on the
    // same stream silently produces nothing. Fresh streams per session fix this.
    private var _transcriptionEvents: AsyncStream<TranscriptionEvent>
    private var _amplitudeStream: AsyncStream<Float>

    public var transcriptionEvents: AsyncStream<TranscriptionEvent> { _transcriptionEvents }
    public var amplitudeStream: AsyncStream<Float> { _amplitudeStream }

    private var _authorizationStatus: SpeechAuthorizationStatus = .notDetermined
    public var authorizationStatus: SpeechAuthorizationStatus { _authorizationStatus }

    public init() {
        var eventCont: AsyncStream<TranscriptionEvent>.Continuation?
        _transcriptionEvents = AsyncStream(bufferingPolicy: .unbounded) { eventCont = $0 }
        eventContinuation = eventCont

        var ampCont: AsyncStream<Float>.Continuation?
        _amplitudeStream = AsyncStream(bufferingPolicy: .unbounded) { ampCont = $0 }
        amplitudeContinuation = ampCont
    }

    /// Create fresh AsyncStreams for a new session.
    /// Must be called before startSession() yields any events.
    private func createFreshStreams() {
        // Finish old streams so any lingering iterators terminate cleanly
        eventContinuation?.finish()
        amplitudeContinuation?.finish()

        var eventCont: AsyncStream<TranscriptionEvent>.Continuation?
        _transcriptionEvents = AsyncStream(bufferingPolicy: .unbounded) { eventCont = $0 }
        eventContinuation = eventCont

        var ampCont: AsyncStream<Float>.Continuation?
        _amplitudeStream = AsyncStream(bufferingPolicy: .unbounded) { ampCont = $0 }
        amplitudeContinuation = ampCont

        logger.info("Fresh AsyncStreams created for new session")
    }

    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            _authorizationStatus = .authorized
        case .denied:
            _authorizationStatus = .denied
        case .restricted:
            _authorizationStatus = .restricted
        case .notDetermined:
            let result = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            switch result {
            case .authorized: _authorizationStatus = .authorized
            case .denied: _authorizationStatus = .denied
            case .restricted: _authorizationStatus = .restricted
            default: _authorizationStatus = .notDetermined
            }
        @unknown default:
            _authorizationStatus = .notDetermined
        }
        return _authorizationStatus
    }

    public func startSession(locale: Locale?, customVocabulary: [String]) async throws -> UUID {
        guard _authorizationStatus == .authorized else {
            throw SpeechEngineError.notAuthorized
        }

        // Verify microphone permission BEFORE touching audioEngine.inputNode
        // Accessing inputNode without mic permission causes CoreAudio -10877 errors
        let micPermission = AVAudioApplication.shared.recordPermission
        guard micPermission == .granted else {
            throw SpeechEngineError.microphoneNotAuthorized
        }

        // Clean up any previous session to avoid "nullptr == Tap()" crash
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        cleanup()

        // Create fresh AsyncStreams — AsyncStream only supports a single iterator,
        // so we MUST create new ones for each session. The ViewModel will read
        // transcriptionEvents/amplitudeStream AFTER this returns and get the new streams.
        createFreshStreams()

        let sessionID = UUID()
        currentSessionID = sessionID
        sessionStartTime = Date()

        let effectiveLocale = locale ?? Locale.current

        // Create speech modules
        let transcriber = DictationTranscriber(
            locale: effectiveLocale,
            contentHints: [],
            transcriptionOptions: [.punctuation, .emoji],
            reportingOptions: [.volatileResults, .frequentFinalization],
            attributeOptions: [.transcriptionConfidence]
        )
        self.transcriber = transcriber

        let detector = SpeechDetector()
        self.detector = detector

        // Ensure locale assets are downloaded and installed on-device
        // This is REQUIRED before SpeechAnalyzer can use the modules
        let modules: [any SpeechModule] = [transcriber, detector]
        let assetStatus = await AssetInventory.status(forModules: modules)
        if assetStatus != .installed {
            if let installRequest = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                try await installRequest.downloadAndInstall()
            } else {
                throw SpeechEngineError.engineNotAvailable
            }
        }

        // Create analysis context with custom vocabulary
        let context = AnalysisContext()
        if !customVocabulary.isEmpty {
            context.contextualStrings[.general] = customVocabulary
        }

        // Create analyzer (SpeechAnalyzer expects the concrete module types)
        let analyzer = SpeechAnalyzer(
            modules: [transcriber, detector],
            options: SpeechAnalyzer.Options(
                priority: .userInitiated,
                modelRetention: .lingering
            )
        )
        self.analyzer = analyzer

        // Get compatible audio format
        let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber, detector]
        )

        guard let format = audioFormat else {
            throw SpeechEngineError.engineNotAvailable
        }

        // Prepare analyzer
        try await analyzer.prepareToAnalyze(in: format)
        try? await analyzer.setContext(context)

        // Create audio input stream — store the continuation so we can finish() it on stop
        let (inputStream, inputCont) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = inputCont

        // Install audio tap
        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Use a larger buffer to avoid CoreAudio overload warnings
        let applyWhisperGain = self.whisperModeEnabled
        let gainMultiplier = self.whisperGainMultiplier

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Apply whisper mode gain boost if enabled
            if applyWhisperGain, let channelData = buffer.floatChannelData {
                let frameCount = Int(buffer.frameLength)
                let channelCount = Int(buffer.format.channelCount)
                for ch in 0..<channelCount {
                    for i in 0..<frameCount {
                        channelData[ch][i] = max(-1.0, min(1.0, channelData[ch][i] * gainMultiplier))
                    }
                }
            }

            // Calculate amplitude for waveform
            if let channelData = buffer.floatChannelData?[0] {
                let frameCount = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameCount {
                    sum += abs(channelData[i])
                }
                let average = sum / Float(max(frameCount, 1))
                self.amplitudeContinuation?.yield(average)
            }

            // Convert to target format if needed
            if hardwareFormat == format {
                let input = AnalyzerInput(buffer: buffer)
                inputCont.yield(input)
            } else if let converter = AVAudioConverter(from: hardwareFormat, to: format) {
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * format.sampleRate / hardwareFormat.sampleRate
                )
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return }
                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                if error == nil {
                    let input = AnalyzerInput(buffer: convertedBuffer)
                    inputCont.yield(input)
                }
            }
        }

        // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            throw SpeechEngineError.audioSessionFailed(underlying: error)
        }

        eventContinuation?.yield(.sessionStarted(sessionID: sessionID))

        // Start analysis
        try await analyzer.start(inputSequence: inputStream)

        // Consume transcription results in background
        // This task is tracked so stopSession() can wait for final results
        transcriptionTask = Task { [weak self] in
            do {
                logger.info("Transcription result loop started for session \(sessionID)")
                for try await result in transcriber.results {
                    guard let self, self.currentSessionID == sessionID else {
                        logger.info("Transcription loop: session mismatch or self deallocated, breaking")
                        break
                    }

                    let text = String(result.text.characters)
                    logger.info("Transcription result: isFinal=\(result.isFinal), length=\(text.count)")
                    let transcriptionResult = TranscriptionResult(
                        text: text,
                        isFinal: result.isFinal,
                        language: effectiveLocale.identifier,
                        sessionID: sessionID
                    )

                    if result.isFinal {
                        self.eventContinuation?.yield(.final(transcriptionResult))
                    } else {
                        self.eventContinuation?.yield(.partial(transcriptionResult))
                    }
                }
                logger.info("Transcription result loop ended normally for session \(sessionID)")
            } catch {
                logger.error("Transcription result loop error: \(error)")
                self?.eventContinuation?.yield(.error(.unknownError(underlying: error)))
            }
        }

        // Consume speech detection results in background
        detectionTask = Task { [weak self] in
            do {
                for try await result in detector.results {
                    guard let self, self.currentSessionID == sessionID else { break }
                    if result.speechDetected {
                        self.amplitudeContinuation?.yield(0.5)
                    }
                }
            } catch {
                // Speech detection errors are non-fatal
                logger.debug("Speech detection loop error (non-fatal): \(error)")
            }
        }

        return sessionID
    }

    public func stopSession() async {
        guard let sessionID = currentSessionID else { return }
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        logger.info("stopSession: finalizing session \(sessionID)...")

        // Stop audio FIRST — stop feeding new audio to the analyzer
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        logger.info("stopSession: audio stopped")

        // CRITICAL: Finish the input stream so the analyzer knows no more audio is coming.
        // Without this, finalizeAndFinishThroughEndOfInput() hangs forever waiting for
        // more input that will never arrive.
        logger.info("stopSession: finishing input stream...")
        inputContinuation?.finish()
        inputContinuation = nil

        // Finalize analysis — processes any remaining buffered audio and produces
        // final results. Now that the input stream is finished, this will complete.
        logger.info("stopSession: finalizing analyzer...")
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        logger.info("stopSession: analyzer finalized")

        // Wait for the transcription task to finish consuming all results
        // (including the final result produced by finalization).
        // Use a timeout to avoid hanging if the transcriber never finishes.
        logger.info("stopSession: waiting for transcription results...")
        let waitTask = Task {
            await transcriptionTask?.value
        }
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(5))
        }
        // Wait for whichever completes first
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await waitTask.value }
            group.addTask { await timeoutTask.value }
            // Take the first one that completes
            await group.next()
            group.cancelAll()
        }
        logger.info("stopSession: transcription consumption complete")

        eventContinuation?.yield(.sessionEnded(sessionID: sessionID, duration: duration))

        cleanup()
    }

    public func cancelSession() async {
        guard let sessionID = currentSessionID else { return }
        logger.info("cancelSession: cancelling session \(sessionID)")

        // Cancel immediately — don't wait for final results
        transcriptionTask?.cancel()
        detectionTask?.cancel()

        // Finish input stream so analyzer doesn't hang
        inputContinuation?.finish()
        inputContinuation = nil

        await analyzer?.cancelAndFinishNow()

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        eventContinuation?.yield(.sessionEnded(sessionID: sessionID, duration: 0))

        cleanup()
    }

    private func cleanup() {
        currentSessionID = nil
        sessionStartTime = nil
        analyzer = nil
        transcriber = nil
        detector = nil
        transcriptionTask = nil
        detectionTask = nil
        inputContinuation = nil
    }
}
