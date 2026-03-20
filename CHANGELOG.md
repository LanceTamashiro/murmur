# Changelog

## [0.1.0] - 2026-03-20

### Phase 1 Foundation — Initial Implementation

#### Core Features
- **On-device voice dictation** using macOS 26 Speech APIs (`DictationTranscriber`, `SpeechAnalyzer`, `SpeechDetector`)
- **Wispr Flow-style floating pill** at bottom of screen — idle (mic icon), recording (waveform + live transcript), completed (checkmark + saved text), error states
- **Globe key push-to-talk** — hold Fn to dictate, release to stop. Cmd+Shift+Space as fallback toggle
- **Text injection** into any focused text field via Accessibility API, with clipboard paste fallback
- **Always-save dictation history** — every dictation is saved as a Note, viewable in the app and menu bar popover
- **Notes library** with NavigationSplitView — list, search, create, edit, trash/restore, pin
- **Menu bar app** with popover showing recent dictations, start dictating button, clinical mode badge
- **Personal dictionary** for custom vocabulary (fed to DictationTranscriber as contextual strings)

#### Onboarding
- 5-step onboarding: Welcome → Microphone Permission → Accessibility Permission → Globe Key Setup → All Set
- Globe key auto-configuration via `defaults write com.apple.HIToolbox AppleFnUsageType -int 0`

#### Technical
- SwiftData models: Note, DictionaryEntry, DictationSession with full CRUD
- MurmurCore SPM package with 5 library targets (Models, NoteStore, SpeechEngine, PersonalDictionary, TextInjection)
- 47 unit tests covering data layer, speech engine mocks, permission flows
- Swift 6 strict concurrency compliance
- Comprehensive `os.log` logging throughout dictation pipeline

#### Reliability Fixes (VoQuill-inspired)
- AX injection verification — reads value back after setting to catch silent failures
- Web area detection — skips AX for browser text fields, goes straight to clipboard
- Bluetooth microphone avoidance — prefers non-Bluetooth input devices
- Clipboard restore delay — 800ms (up from 200ms) for Electron-based apps
- Multi-monitor cursor following — flow bar appears on screen containing cursor

#### Bug Fixes
- Fixed `nullptr == Tap()` crash — remove existing audio tap before installing new one
- Fixed CoreAudio `-10877` errors — lazy `AVAudioEngine` initialization, mic permission before audio access
- Fixed `Cannot use modules with unallocated locales` — `AssetInventory` locale model download before SpeechAnalyzer use
- Fixed `finalizeAndFinishThroughEndOfInput` hang — call `inputContinuation.finish()` before analyzer finalization
- Fixed second recording dead — create fresh `AsyncStream`s per session (single-iterator limitation)
- Fixed premature finalization — accumulate sentence-boundary `isFinal` results, only save on `sessionEnded`
