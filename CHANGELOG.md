# Changelog

## [0.1.3] - 2026-03-20

### Fixed
- **Fixed text injection permanently failing** — root cause was `CODE_SIGN_IDENTITY: "-"` (ad-hoc signing) which generated a new code signature on every Xcode rebuild, causing macOS TCC to "forget" the accessibility permission grant. Switched to proper Apple Development signing with team ID.
- Fixed race condition where cancelling dictation during startup would surface a CancellationError instead of cleanly resetting to idle.

### Changed
- Code signing: `CODE_SIGN_IDENTITY` changed from `"-"` (ad-hoc) to `"Apple Development"` with `DEVELOPMENT_TEAM: "6JV343TBM7"`. TCC accessibility grants now persist across rebuilds.
- Injection activation delay increased from 150ms to 300ms for more reliable target app focus.
- Clipboard paste fallback now always attempted (removed `AXIsProcessTrusted()` gate).
- AXTextInjector now logs raw `AXError` codes for better diagnostics (distinguishes apiDisabled vs cannotComplete vs noValue).
- Test count: 64 → 79 (64 MurmurCore + 15 MurmurTests).

## [0.1.2] - 2026-03-20

### Fixed
- Fixed text injection failing silently when accessibility permission is stale (common with Xcode debug rebuilds). Now actively prompts via system dialog, opens System Settings, polls for up to 8 seconds, and retries injection automatically once granted.

### Changed
- Note titles are now auto-derived from body text (first 50 chars) instead of being set manually. Removes `title` parameter from `createNote` and `updateNote` APIs.
- Test count: 60 → 64.

## [0.1.1] - 2026-03-20

### Fixed
- Fixed crash on 2nd dictation — layout recursion in HUD pill window (`NSGenericException` from `setContentSize` during layout). Replaced with cancellable `DispatchWorkItem` and 2pt threshold to coalesce rapid resize requests.
- Fixed text injection targeting Murmur itself — `AppContextDetector` now excludes Murmur, with fallback to `NSWorkspace.shared.frontmostApplication` when no external app has been seen yet.
- Fixed silent injection failure without accessibility — `CGEvent.post` silently drops Cmd+V without accessibility permission. Now returns `.noAccessibilityPermission` and shows a clear error in the HUD pill.
- Fixed onboarding threading crash (`_dispatch_assert_queue_fail`) — `SFSpeechRecognizer.requestAuthorization` fires its callback on a background queue, causing `@State` mutations off main thread. Extracted permission logic into `@MainActor` `OnboardingPermissionCoordinator` with mockable `PermissionProvider` protocol.
- Fixed system permission dialogs appearing outside onboarding — removed redundant `requestAuthorizationIfNeeded()` from `AppDelegate.setup()`, all permissions now handled exclusively in onboarding flow.
- Fixed onboarding window not appearing on relaunch — added `applicationDidFinishLaunching` to activate app and show main window.
- Fixed Globe Key step blocking main thread — moved `Process().waitUntilExit()` to `Task.detached`.

### Changed
- Onboarding mic step now requests both microphone AND speech recognition permissions in a single step.
- Accessibility onboarding step shows "I've already granted access" button after 5 seconds of polling (works around Xcode debug build TCC quirk).
- `AppDelegate.setup()` only runs after onboarding completes (moved from `.task` on Group to `.task` on ContentView).

### Added
- `OnboardingPermissionCoordinator` — testable `@MainActor` coordinator for mic/speech permission requests with `PermissionProvider` protocol.
- 13 new tests: 8 onboarding permission regression tests (including background-callback crash scenario), 5 threading safety contract tests.
- Test count: 47 → 60.

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
