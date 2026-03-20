import Foundation

public enum InjectionResult: Sendable {
    case success(strategy: InjectionStrategy)
    case failed(error: InjectionError)
    case skipped(reason: SkipReason)

    public enum SkipReason: Sendable {
        case noFocusedTextField
        case userDisabledInjection
        case appOptedOut
    }
}

public enum InjectionStrategy: String, Sendable {
    case accessibilityDirect
    case accessibilityKeystrokes
    case clipboardPaste
}

public enum InjectionError: Error, Sendable {
    case accessibilityPermissionDenied
    case noFocusedElement
    case elementNotWritable
    case verificationFailed(expected: Int, actual: Int)
    case clipboardOperationFailed
    case unknownError(underlying: any Error)
}

public struct AppContext: Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let processID: Int32

    public init(bundleIdentifier: String, displayName: String, processID: Int32) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.processID = processID
    }
}
