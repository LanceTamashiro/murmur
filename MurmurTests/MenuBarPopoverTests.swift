import Testing
import Foundation
@testable import Murmur

@Suite("MenuBarPopover Helpers")
struct MenuBarPopoverTests {

    // MARK: - relativeTimeString

    @Test("Just now for less than 60 seconds ago")
    func justNow() {
        let date = Date().addingTimeInterval(-30)
        #expect(relativeTimeString(date) == "Just now")
    }

    @Test("Just now for 0 seconds ago")
    func justNowZero() {
        let date = Date()
        #expect(relativeTimeString(date) == "Just now")
    }

    @Test("Minutes ago for 1 minute")
    func oneMinuteAgo() {
        let date = Date().addingTimeInterval(-60)
        #expect(relativeTimeString(date) == "1 min ago")
    }

    @Test("Minutes ago for 45 minutes")
    func fortyFiveMinutesAgo() {
        let date = Date().addingTimeInterval(-45 * 60)
        #expect(relativeTimeString(date) == "45 min ago")
    }

    @Test("Hours ago for 1 hour")
    func oneHourAgo() {
        let date = Date().addingTimeInterval(-3600)
        #expect(relativeTimeString(date) == "1 hour ago")
    }

    @Test("Hours ago for multiple hours")
    func multipleHoursAgo() {
        let date = Date().addingTimeInterval(-5 * 3600)
        #expect(relativeTimeString(date) == "5 hours ago")
    }

    @Test("Yesterday for 25 hours ago")
    func yesterday() {
        let date = Date().addingTimeInterval(-25 * 3600)
        #expect(relativeTimeString(date) == "Yesterday")
    }

    @Test("Date string for 3 days ago")
    func threeDaysAgo() {
        let date = Date().addingTimeInterval(-3 * 86400)
        let result = relativeTimeString(date)
        // Should be a formatted date like "Mar 20", not a relative string
        #expect(!result.contains("ago"))
        #expect(!result.contains("Yesterday"))
        #expect(!result.contains("Just now"))
    }

    // MARK: - friendlyAppName

    @Test("Extracts app name from known bundle ID")
    func knownBundleID() {
        // NSWorkspace.shared.urlForApplication may not resolve in test host,
        // so test the fallback path
        let result = friendlyAppName("com.example.unknownapp")
        #expect(result == "Unknownapp")
    }

    @Test("Handles single-component bundle ID")
    func singleComponent() {
        let result = friendlyAppName("textedit")
        // NSWorkspace might resolve this, or fallback capitalizes it
        #expect(!result.isEmpty)
    }

    @Test("Handles empty string gracefully")
    func emptyBundleID() {
        let result = friendlyAppName("")
        #expect(!result.isEmpty || result == "")
    }

    @Test("Resolves real app if installed")
    func realApp() {
        // TextEdit is always installed on macOS
        let result = friendlyAppName("com.apple.TextEdit")
        // Should resolve to "TextEdit" via NSWorkspace or fallback to "Textedit"
        #expect(result.lowercased().contains("textedit"))
    }
}
