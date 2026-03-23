/// Protocol for AI editing providers (OpenAI, Claude, Apple Intelligence, etc.).
///
/// Providers receive pre-processed text and return AI-enhanced text with grammar
/// correction, tone adaptation, command execution, and other transformations.
public protocol AIEditingProvider: Sendable {
    /// Unique identifier for this provider instance.
    var id: String { get }

    /// Human-readable name (e.g., "OpenAI GPT-4o").
    var displayName: String { get }

    /// Process an editing request and return the result.
    func process(_ request: EditingRequest) async throws -> EditingResult

    /// Check if this provider is currently available (API key configured, model downloaded, etc.).
    func isAvailable() async -> Bool
}

/// Errors that can occur during AI editing.
public enum AIEditingError: Error, Sendable {
    case providerUnavailable(String)
    case apiError(String)
    case timeout
    case invalidResponse
    case allProvidersFailed
}
