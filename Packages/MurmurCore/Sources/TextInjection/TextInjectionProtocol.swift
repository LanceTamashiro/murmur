import Foundation

public protocol TextInjectionProtocol: AnyObject, Sendable {
    var currentAppContext: AppContext? { get }
    var appContextChanges: AsyncStream<AppContext?> { get }

    func inject(text: String, preferredStrategy: InjectionStrategy, allowFallback: Bool) async -> InjectionResult
    func replaceSelection(with text: String) async -> InjectionResult

    var hasAccessibilityPermission: Bool { get }
    func openAccessibilityPreferences()
}
