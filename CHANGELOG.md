# Changelog

## [0.3.0] - 2026-03-23

### Added
- **AI editing pipeline** — optional AI-powered text cleanup via Claude or OpenAI providers (filler word removal, backtrack correction, command mode, and AI rewriting). Configurable per-provider in new AI Editing settings tab.
- **Keychain-backed API key storage** — provider API keys stored securely in macOS Keychain, never in UserDefaults.
- **Markdown preview** — split-view editor mode with live markdown rendering alongside the source text.
- **Note preview in menu bar** — tap any recent dictation to see the full note text, copy it, or trash it without opening the Notes Library.
- **Quick-copy button** — each menu bar row has a copy icon for one-tap clipboard access with visual "Copied!" feedback.
- **MenuBarPopoverTests** — 12 tests covering relative time formatting and app name resolution helpers.

### Changed
- **Stable timestamps in menu bar** — replaced constantly-updating relative times ("5 min, 59 sec") with static labels ("3 min ago", "Yesterday", "Mar 20") that don't cause visual jitter.
- **Friendly source app names** — menu bar rows now show "Claude" instead of "com.anthropic.claudefordesktop" by resolving bundle IDs via NSWorkspace.
- **Menu bar navigation** — tapping a dictation row now pushes a detail view (via NavigationStack) instead of silently copying text.

## [0.2.0] - 2026-03-21

### Added
- **Session recovery** — in-progress dictations are saved every 10 seconds (AES-256-GCM encrypted, Keychain-backed key). On relaunch after a crash, recovered text is automatically restored as a note.
- **Export notes** — export any note as Markdown (.md), Plain Text (.txt), or PDF from the editor toolbar.
- **Quick note from menu bar** — type and save a note directly from the menu bar popover without starting a dictation session.
- **Microphone selection** — new Audio settings tab with a device picker and live level meter for testing.
- **Whisper mode** — +12dB gain boost for quiet environments, toggled in Audio settings.
- **Expanded session history** — menu bar popover now shows up to 50 recent dictations (was 5).
- **SessionRecoveryTests** — 4 tests covering encoding/decoding, restore-as-note, no-file check, and periodic save lifecycle.

### Changed
- **Privacy hardening** — removed unused `com.apple.security.network.client` entitlement; redacted all transcription text from os.log (char counts only); removed clinical mode references throughout.
- Menu bar popover shows "On-Device" privacy badge instead of clinical mode toggle.

### Fixed
- **Flaky TextInjectionTests** — replaced fixed sleeps with AX readiness polling (`waitForWritableElement`), added `.serialized` to prevent concurrent TextEdit launches, and added single-retry injection. Tests now pass reliably across 3+ consecutive runs.

## [0.1.8] - 2026-03-20

### Added
- **App icon** — custom waveform icon (indigo-to-violet gradient with white audio bars in macOS squircle shape) across all 10 required macOS sizes. Previously showed generic Xcode app icon.
- `scripts/generate-icons.py` — reusable Pillow script to regenerate icons if design needs tweaking.

### Fixed
- **App icon not appearing in Dock/Finder** — asset catalog entries had invalid `"platform": "macOS"` key causing `actool` to silently skip compilation. Removed platform key and added `INFOPLIST_KEY_CFBundleIconName` to project.yml so Info.plist correctly references the icon.

## [0.1.7] - 2026-03-20

### Added
- **Test runner script** (`scripts/run-tests.sh`) — runs all tests reliably by executing each MurmurTests suite individually, working around the macOS 26 beta BSBlockSentinel test-host crash. Rebuilds before each suite and checks actual Swift Testing output rather than xcodebuild exit codes.

### Changed
- CLAUDE.md updated to use `./scripts/run-tests.sh` as the primary test command, preventing agents from hitting the BSBlockSentinel crash.

## [0.1.6] - 2026-03-20

### Added
- **Personal Dictionary UI** — full management interface in Settings: list, add/edit sheets, search, swipe-to-delete, suppress/enable toggle, context menus. No longer a placeholder.
- **Session timer in HUD** — recording pill now shows elapsed time (MM:SS) during dictation.
- **Configurable trigger keys** — choose between Fn (Globe), Right Option, Right Command, or Caps Lock for push-to-talk in Settings > Dictation.
- **Toggle mode max duration** — auto-stops recording after configurable timeout (1/2/5/10 min or no limit, default 5 min). Prevents runaway sessions.
- **300ms hold duration guard** — accidental Fn taps shorter than 300ms are cancelled instead of injecting empty text.
- 9 new tests: TriggerKey enum validation (5), toggle/cancel state management (4).

### Changed
- `GlobalHotkeyMonitor` refactored from hardcoded Fn key to configurable `TriggerKey` enum.
- `sessionStartTime` exposed for HUD timer display.
- Settings scene now has `.modelContainer` for SwiftData queries in dictionary tab.
- Test count: 83 → 92.

## [0.1.5] - 2026-03-20

### Fixed
- **Fixed HUD constraint recursion crash** — `NSHostingView.updateConstraints()` triggered recursive `setNeedsUpdateConstraints` via internal view graph invalidation. Set `sizingOptions = []` to prevent hosting view from driving window constraints, with manual sizing in `layout()` and re-entrancy guard.

### Changed
- **Text injection is now ~3-4x faster** — inject accumulated text immediately on globe key release instead of waiting for analyzer finalization. Finalization now runs in the background; any tail text updates the saved note. AX injection drops from ~650ms to ~175ms, clipboard fallback from ~1650ms to ~300ms.
- App reactivation delay: replaced fixed 300ms sleep with polling loop (25ms intervals, 150ms max). Most apps activate in 25-50ms.
- Clipboard paste restore delay: reduced from 800ms to 200ms. The Cmd+V event has already been posted; 200ms is sufficient.
- Test count: 79 → 83 (4 new early injection tests).

## [0.1.4] - 2026-03-20

### Changed
- **Copy button is now prominent** — upgraded from tiny caption-sized borderless text to a filled, accent-colored button in the editor toolbar. Added ⌘⇧C keyboard shortcut.

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
