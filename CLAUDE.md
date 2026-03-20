# Murmur — Project Instructions

## Overview

Murmur is a macOS 26+ voice dictation and intelligent notes app for Unconventional Psychotherapy (2-10 employees). Built with Swift 6, SwiftUI, SwiftData, and on-device macOS 26 Speech APIs (`DictationTranscriber`, `SpeechAnalyzer`, `SpeechDetector`).

## Build & Test

```bash
# Build the app
cd /Users/lance/Documents/Murmur
xcodebuild build -scheme Murmur -destination 'platform=macOS'

# Run MurmurCore unit tests
cd /Users/lance/Documents/Murmur/Packages/MurmurCore
swift test

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
- **Sentence-boundary isFinal:** `DictationTranscriber` produces `isFinal=true` at sentence boundaries, not just session end. The ViewModel accumulates these into `finalizedSegments[]` and only saves/injects on `sessionEnded`.
- **Globe key requires accessibility + "Do Nothing" setting:** `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` silently fails without accessibility permission. Globe key (keyCode 63) only fires if `AppleFnUsageType = 0`.
- **Always save as note:** Every dictation is saved as a Note regardless of whether text injection succeeds. History is always preserved.
- **System callback threading:** `SFSpeechRecognizer.requestAuthorization` fires on a background queue. `withCheckedContinuation` does NOT hop back to `@MainActor` — use `await MainActor.run { }` or extract logic into `@MainActor` classes. Never rely on `@MainActor` annotations on struct methods for continuation safety.
- **CGEvent.post requires accessibility:** `CGEvent.post(tap: .cghidEventTap)` silently drops events without accessibility permission. Always check `AXIsProcessTrusted()` before attempting clipboard paste injection.
- **Onboarding before setup:** `AppDelegate.setup()` only runs after `onboardingCompleted = true`. All permission requests happen in the onboarding flow, not in setup.
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
| Full spec | `requirements-spec.md` |
| Plan | `.claude/plans/warm-gliding-aho.md` |

## Testing

- 60 tests across 5 suites: NoteStoreService, PersonalDictionaryService, MockSpeechEngine, OnboardingPermissionCoordinator, ThreadingSafety
- All tests use in-memory `ModelContainer`, `MockSpeechEngine`, or `BackgroundCallbackPermissionProvider`
- Tests cover: CRUD, search, trash/restore, auth flows, mic permission, session lifecycle, event streaming, error types, threading safety, onboarding permission flow
- Swift 6 strict concurrency: async stream tests use `actor`-based collectors for Sendable safety
- Threading regression tests: `BackgroundCallbackPermissionProvider` fires callbacks on `DispatchQueue.global()` to reproduce the exact crash scenario from `SFSpeechRecognizer`
