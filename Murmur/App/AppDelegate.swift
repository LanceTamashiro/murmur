import AppKit
import SwiftUI
import SwiftData
import Models
import NoteStore
import SpeechEngine
import PersonalDictionary
import os.log

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "AppDelegate")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyMonitor: GlobalHotkeyMonitor?
    private var hudWindow: DictationHUDWindow?
    private var dictationViewModel: DictationViewModel?
    private var textInjectionService: TextInjectionService?
    private var setupCompleted = false

    func setup(
        modelContainer: ModelContainer,
        dictationViewModel: DictationViewModel
    ) {
        guard !setupCompleted else { return }
        setupCompleted = true

        self.dictationViewModel = dictationViewModel

        // Set up text injection
        let appContextDetector = AppContextDetector()
        let injectionService = TextInjectionService(appContextDetector: appContextDetector)
        self.textInjectionService = injectionService

        // Set up speech engine
        let speechEngine = DictationTranscriberEngine()

        // Set up note store and personal dictionary
        let noteStore = NoteStoreService(modelContainer: modelContainer)
        let personalDictionary = PersonalDictionaryService(modelContainer: modelContainer)

        // Configure dictation view model
        dictationViewModel.configure(
            speechEngine: speechEngine,
            textInjectionService: injectionService,
            noteStore: noteStore,
            personalDictionary: personalDictionary
        )

        // Re-verify mic + speech permissions on every launch — they may have been
        // revoked since onboarding completed. This is a no-op if already granted.
        dictationViewModel.requestAuthorizationIfNeeded()

        // Prompt for accessibility permission if not granted — required for text
        // injection (AX API) and global hotkey monitoring (CGEvent). The prompt
        // option opens the System Settings dialog directing the user to grant access.
        if !AXIsProcessTrusted() && ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            logger.warning("setup: accessibility permission not granted — prompted user")
        }

        // Set up menu bar
        let menuBar = MenuBarController()
        menuBar.setup { [weak self] in
            AnyView(
                MenuBarPopoverView(
                    onStartDictating: { self?.handleToggle() },
                    onOpenLibrary: { self?.openMainWindow() }
                )
            )
        }
        menuBarController = menuBar

        // Set up hotkeys: Fn (push-to-talk) + Cmd+Shift+Space (toggle)
        let triggerKeyRaw = UserDefaults.standard.string(forKey: "triggerKey") ?? "fn"
        let triggerKey = TriggerKey(rawValue: triggerKeyRaw) ?? .fn

        let hotkey = GlobalHotkeyMonitor()
        hotkey.start(
            triggerKey: triggerKey,
            onFnDown: { [weak self] in self?.handleFnDown() },
            onFnUp: { [weak self] in self?.handleFnUp() },
            onFnCancel: { [weak self] in self?.handleFnCancel() },
            onToggle: { [weak self] in self?.handleToggle() }
        )
        hotkeyMonitor = hotkey

        // Show the flow bar pill at bottom of screen
        showFlowBar()
    }

    // MARK: - Toggle (Cmd+Shift+Space or "Start Dictating" button)

    private func handleToggle() {
        guard let dictationViewModel else { return }
        logger.info("handleToggle called — current state: \(String(describing: dictationViewModel.state))")

        dictationViewModel.toggle()

        // Update menu bar icon based on new state
        switch dictationViewModel.state {
        case .recording:
            menuBarController?.iconState = .listening
        case .processing:
            menuBarController?.iconState = .processing
        case .idle:
            menuBarController?.iconState = .idle
        case .error:
            menuBarController?.iconState = .error
        default:
            break
        }
    }

    // MARK: - Push-to-Talk (Fn key)

    private func handleFnDown() {
        guard let dictationViewModel else { return }
        logger.info("handleFnDown called — current state: \(String(describing: dictationViewModel.state))")
        guard case .idle = dictationViewModel.state else {
            logger.warning("handleFnDown: not idle, ignoring (state=\(String(describing: dictationViewModel.state)))")
            return
        }

        dictationViewModel.startDictation()
        menuBarController?.iconState = .listening
    }

    private func handleFnCancel() {
        guard let dictationViewModel else { return }
        logger.info("handleFnCancel: hold too short (<300ms) — cancelling")
        dictationViewModel.cancel()
        menuBarController?.iconState = .idle
    }

    private func handleFnUp() {
        guard let dictationViewModel else { return }
        logger.info("handleFnUp called — current state: \(String(describing: dictationViewModel.state))")
        guard case .recording = dictationViewModel.state else {
            logger.warning("handleFnUp: not recording, ignoring (state=\(String(describing: dictationViewModel.state)))")
            return
        }

        dictationViewModel.stopAndInject()
        menuBarController?.iconState = .processing

        // Reset icon after processing completes
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if case .idle = dictationViewModel.state {
                menuBarController?.iconState = .idle
            }
        }
    }

    // MARK: - Flow Bar (always visible at bottom center)

    private func showFlowBar() {
        guard let dictationViewModel else { return }

        let hudView = DictationHUDView()
            .environment(dictationViewModel)
        let hostingView = AutoResizingHostingView(rootView: hudView)

        // Let the hosting view size itself to fit its SwiftUI content
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)

        let window = DictationHUDWindow(contentView: hostingView)
        window.setContentSize(fittingSize)
        hudWindow = window
        window.showHUD()
    }

    // MARK: - Window Management

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the main window is visible on launch (macOS window restoration
        // may suppress it if the user closed it in a previous session).
        // No DispatchQueue.main.async — AppDelegate is @MainActor, already on main.
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor?.stop()
    }
}
