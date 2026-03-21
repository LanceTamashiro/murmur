# Murmur — Project Instructions

## Overview

Murmur is a macOS 26+ voice dictation and intelligent notes app for Unconventional Psychotherapy (2-10 employees). Built with Swift 6, SwiftUI, SwiftData, and on-device macOS 26 Speech APIs (`DictationTranscriber`, `SpeechAnalyzer`, `SpeechDetector`).

## Build & Test

```bash
# Run ALL tests (recommended — works around macOS 26 beta test-host crash)
cd /Users/lance/Documents/Murmur
./scripts/run-tests.sh

# Build the app only
xcodebuild build -scheme Murmur -destination 'platform=macOS'

# Run MurmurCore SPM tests only
cd /Users/lance/Documents/Murmur/Packages/MurmurCore
swift test

# Run a single MurmurTests suite (must run individually, not all at once)
cd /Users/lance/Documents/Murmur
xcodebuild test -scheme Murmur -destination 'platform=macOS' \
  -only-testing:MurmurTests/DictationViewModelRaceTests

# Regenerate Xcode project after adding/removing files
xcodegen generate
```

## Architecture

- **App target:** `Murmur/` — macOS app with SwiftUI views, AppKit integration (NSPanel, NSStatusItem, CGEventTap)
- **Core package:** `Packages/MurmurCore/` — SPM package with 5 library targets:
  - `Models` — SwiftData `@Model` types (Note, DictionaryEntry, DictationSession)
  - `NoteStore` — CRUD operations on Notes via SwiftData
  - `SpeechEngine` — `SpeechEngineProtocol`, `DictationTranscriberEngine` (real), `MockSpeechEngine` (tests)
  - `PersonalDictionary` — Custom vocabulary management
  - `TextInjection` — Types for AX/clipboard text injection

## Key Technical Decisions

- **AsyncStream per session:** `DictationTranscriberEngine` creates fresh `AsyncStream`s for each session via `createFreshStreams()`. AsyncStream only supports a single iterator — reusing streams across sessions causes silent failures.
- **Lazy AVAudioEngine:** `audioEngine` is `lazy var` to avoid CoreAudio `-10877` errors before mic permission is granted.
- **Input stream finish:** Must call `inputContinuation?.finish()` before `analyzer.finalizeAndFinishThroughEndOfInput()` — otherwise the analyzer hangs waiting for more audio.
- **Sentence-boundary isFinal:** `DictationTranscriber` produces `isFinal=true` at sentence boundaries, not just session end. The ViewModel accumulates these into `finalizedSegments[]`.
- **Early injection on key release:** When the globe key is released, `stopDictation()` captures the already-accumulated text (`finalizedSegments` + partial from `liveTranscript`) and injects it immediately — without waiting for `speechEngine.stopSession()` to finalize. Analyzer finalization runs in the background; if it produces additional tail text, the saved note is updated via `noteStore.updateNote()`. The `earlyInjectionNoteID`/`earlyInjectionText` properties track this.
- **HUD sizing must not use NSHostingView constraints:** `AutoResizingHostingView` sets `sizingOptions = []` to prevent `NSHostingView` from driving window constraints. Without this, the hosting view's internal view graph evaluation during `updateConstraints()` triggers `setNeedsUpdateConstraints`, creating a recursive constraint loop that crashes. Window sizing is managed manually in `layout()` with a deferred `DispatchQueue.main.async` and a `resizeScheduled` re-entrancy guard.
- **Configurable trigger keys via `TriggerKey` enum:** `GlobalHotkeyMonitor` accepts a `TriggerKey` parameter (`.fn`, `.rightOption`, `.rightCommand`, `.capsLock`). Each case maps to a `keyCode` and `modifierFlag`. The setting is stored in `@AppStorage("triggerKey")` and read in `AppDelegate.setup()`. Changing the trigger key requires an app restart.
- **300ms minimum hold duration:** `GlobalHotkeyMonitor` tracks press time and fires `onFnCancel` instead of `onFnUp` for holds shorter than 300ms, preventing accidental triggers. The cancel callback is wired to `DictationViewModel.cancel()`.
- **Toggle mode max duration:** When dictation starts via `toggle()`, a `maxDurationTask` auto-stops recording after `toggleMaxDuration` seconds (default 300s / 5 min, stored in `@AppStorage("toggleMaxDuration")`). Set to 0 for no limit. The task is cancelled on manual stop/cancel.
- **Globe key requires accessibility + "Do Nothing" setting:** `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` silently fails without accessibility permission. Globe key (keyCode 63) only fires if `AppleFnUsageType = 0`.
- **Always save as note:** Every dictation is saved as a Note regardless of whether text injection succeeds. History is always preserved.
- **System callback threading:** `SFSpeechRecognizer.requestAuthorization` fires on a background queue. `withCheckedContinuation` does NOT hop back to `@MainActor` — use `await MainActor.run { }` or extract logic into `@MainActor` classes. Never rely on `@MainActor` annotations on struct methods for continuation safety.
- **CGEvent.post requires accessibility:** `CGEvent.post(tap: .cghidEventTap)` silently drops events without accessibility permission. Always check `AXIsProcessTrusted()` before attempting clipboard paste injection.
- **Onboarding before setup:** `AppDelegate.setup()` only runs after `onboardingCompleted = true`. All permission requests happen in the onboarding flow, not in setup.
- **Code signing must use Apple Development (not ad-hoc):** `CODE_SIGN_IDENTITY` must be `"Apple Development"` with a real `DEVELOPMENT_TEAM`. Ad-hoc signing (`"-"`) generates a new code signature per rebuild, causing TCC to forget accessibility grants. This was the root cause of persistent text injection failures.
- **Xcode debug builds + accessibility:** TCC accessibility grants may not take effect until the debug build is relaunched. Onboarding handles this with a "I've already granted access" fallback button.
- **Non-sandboxed debug plist:** Xcode debug builds use `~/Library/Preferences/com.unconventionalpsychotherapy.murmur.plist`, not the sandboxed container. Reset onboarding with: `defaults write ~/Library/Preferences/com.unconventionalpsychotherapy.murmur.plist onboardingCompleted -bool false`

## Debugging

- Filter Console.app for subsystem `com.unconventionalpsychotherapy.murmur`
- Categories: `AppDelegate`, `DictationViewModel`, `SpeechEngine`, `HotkeyMonitor`
- Key log messages: "Globe key DOWN", "startDictation: beginning...", "Transcription result:", "Session ended", "saveAsNote:"

## File Locations

| Purpose | Path |
|---|---|
| App entry point | `Murmur/App/MurmurApp.swift` |
| App delegate (wiring) | `Murmur/App/AppDelegate.swift` |
| Speech engine (real) | `Packages/MurmurCore/Sources/SpeechEngine/DictationTranscriberEngine.swift` |
| Speech engine (mock) | `Packages/MurmurCore/Sources/SpeechEngine/MockSpeechEngine.swift` |
| Dictation orchestration | `Murmur/ViewModels/DictationViewModel.swift` |
| Flow bar pill | `Murmur/Views/Dictation/DictationHUDView.swift` |
| Globe key monitor | `Murmur/macOS/HotkeyMonitor/GlobalHotkeyMonitor.swift` |
| Text injection | `Murmur/macOS/TextInjection/` |
| Session recovery | `Murmur/Services/SessionRecoveryManager.swift` |
| Note exporter | `Murmur/Services/NoteExporter.swift` |
| Audio settings | `Murmur/Views/Settings/AudioSettingsView.swift` |
| Full spec | `requirements-spec.md` |
| Plan | `.claude/plans/reactive-imagining-kurzweil.md` |

## Testing

- 96+ tests across 13 suites: NoteStoreService, PersonalDictionaryService, MockSpeechEngine, OnboardingPermissionCoordinator, ThreadingSafety (MurmurCore: 64), plus DictationViewModelRace, EarlyInjection, TextInjection, MockSpeechEngineRace, AppDelegateSetup, TriggerKey, ToggleMaxDuration, SessionRecovery (MurmurTests: 32+)
- All tests use in-memory `ModelContainer`, `MockSpeechEngine`, or `BackgroundCallbackPermissionProvider`
- Tests cover: CRUD, search, trash/restore, auth flows, mic permission, session lifecycle, event streaming, error types, threading safety, onboarding permission flow, race conditions, early injection (snapshot text, tail text update, empty snapshot fallback, no double injection), text injection into TextEdit, TriggerKey enum validation, toggle/cancel state management, session recovery (encode/decode, restore, periodic save)
- TextInjection tests launch TextEdit, inject text via AX API, and verify it arrived — require accessibility permission (skip if not granted). Tests use `.serialized` and AX readiness polling for reliability.
- Swift 6 strict concurrency: async stream tests use `actor`-based collectors for Sendable safety
- Threading regression tests: `BackgroundCallbackPermissionProvider` fires callbacks on `DispatchQueue.global()` to reproduce the exact crash scenario from `SFSpeechRecognizer`
- **Do NOT run `xcodebuild test -scheme Murmur` without `-only-testing:`** — macOS 26 beta crashes the test host (`BSBlockSentinel:FBSWorkspaceScenesClient`). Always use `./scripts/run-tests.sh` which rebuilds and runs each suite separately, checking actual Swift Testing output rather than xcodebuild exit codes.
