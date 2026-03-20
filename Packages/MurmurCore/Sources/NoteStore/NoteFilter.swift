import Foundation

public struct NoteFilter: Sendable {
    public var includeTrashed: Bool
    public var pinnedOnly: Bool
    public var dateRange: DateInterval?
    public var language: String?
    public var sourceApp: String?

    public init(
        includeTrashed: Bool = false,
        pinnedOnly: Bool = false,
        dateRange: DateInterval? = nil,
        language: String? = nil,
        sourceApp: String? = nil
    ) {
        self.includeTrashed = includeTrashed
        self.pinnedOnly = pinnedOnly
        self.dateRange = dateRange
        self.language = language
        self.sourceApp = sourceApp
    }

    public static let `default` = NoteFilter()
}
