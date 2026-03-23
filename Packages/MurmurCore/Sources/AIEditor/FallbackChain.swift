import Foundation

/// A chain of AI editing providers that tries each in order until one succeeds.
///
/// Implements a circuit breaker pattern: providers that fail repeatedly are
/// temporarily removed from the active chain to avoid latency penalties.
public final class FallbackChain: AIEditingProvider, @unchecked Sendable {

    public let id = "fallback-chain"
    public let displayName = "Fallback Chain"

    private let providers: [any AIEditingProvider]
    private let lock = NSLock()

    /// Failure tracking per provider for circuit breaker
    private var failureHistory: [String: [Date]] = [:]

    /// Providers currently in cooldown (circuit breaker tripped)
    private var cooldownUntil: [String: Date] = [:]

    /// Number of failures within the window that triggers cooldown
    private let failureThreshold: Int

    /// Time window for counting failures (seconds)
    private let failureWindow: TimeInterval

    /// Cooldown duration after circuit breaker trips (seconds)
    private let cooldownDuration: TimeInterval

    public init(
        providers: [any AIEditingProvider],
        failureThreshold: Int = 5,
        failureWindow: TimeInterval = 600, // 10 minutes
        cooldownDuration: TimeInterval = 300 // 5 minutes
    ) {
        self.providers = providers
        self.failureThreshold = failureThreshold
        self.failureWindow = failureWindow
        self.cooldownDuration = cooldownDuration
    }

    public func isAvailable() async -> Bool {
        for provider in providers {
            if !isInCooldown(provider.id), await provider.isAvailable() {
                return true
            }
        }
        return false
    }

    public func process(_ request: EditingRequest) async throws -> EditingResult {
        var lastError: Error?

        for provider in providers {
            // Skip providers in cooldown
            if isInCooldown(provider.id) {
                continue
            }

            // Skip unavailable providers
            guard await provider.isAvailable() else {
                continue
            }

            do {
                let result = try await provider.process(request)
                // Success — clear failure history for this provider
                clearFailures(for: provider.id)
                return result
            } catch {
                lastError = error
                recordFailure(for: provider.id)
            }
        }

        throw lastError ?? AIEditingError.allProvidersFailed
    }

    // MARK: - Circuit Breaker

    private func isInCooldown(_ providerID: String) -> Bool {
        lock.withLock {
            guard let until = cooldownUntil[providerID] else { return false }
            if Date() >= until {
                cooldownUntil.removeValue(forKey: providerID)
                return false
            }
            return true
        }
    }

    private func recordFailure(for providerID: String) {
        lock.withLock {
            let now = Date()
            var history = failureHistory[providerID] ?? []

            // Remove old entries outside the window
            let windowStart = now.addingTimeInterval(-failureWindow)
            history = history.filter { $0 > windowStart }

            history.append(now)
            failureHistory[providerID] = history

            // Check if threshold exceeded
            if history.count >= failureThreshold {
                cooldownUntil[providerID] = now.addingTimeInterval(cooldownDuration)
                failureHistory[providerID] = []
            }
        }
    }

    private func clearFailures(for providerID: String) {
        lock.withLock {
            failureHistory.removeValue(forKey: providerID)
            cooldownUntil.removeValue(forKey: providerID)
        }
    }
}
