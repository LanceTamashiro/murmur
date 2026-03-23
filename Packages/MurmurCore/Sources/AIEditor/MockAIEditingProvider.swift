import Foundation

/// A mock AI editing provider for testing. Returns configurable output.
public final class MockAIEditingProvider: AIEditingProvider, @unchecked Sendable {
    public let id: String
    public let displayName: String

    private let lock = NSLock()
    private var _available: Bool
    private var _transform: @Sendable (String) -> String
    private var _shouldFail: Bool
    private var _processCount: Int = 0

    /// Number of times `process` has been called.
    public var processCount: Int {
        lock.withLock { _processCount }
    }

    public init(
        id: String = "mock",
        displayName: String = "Mock Provider",
        available: Bool = true,
        shouldFail: Bool = false,
        transform: @escaping @Sendable (String) -> String = { $0 }
    ) {
        self.id = id
        self.displayName = displayName
        self._available = available
        self._shouldFail = shouldFail
        self._transform = transform
    }

    public func process(_ request: EditingRequest) async throws -> EditingResult {
        lock.withLock { _processCount += 1 }

        let shouldFail = lock.withLock { _shouldFail }
        if shouldFail {
            throw AIEditingError.apiError("Mock provider configured to fail")
        }

        let transform = lock.withLock { _transform }
        let processed = transform(request.text)

        return EditingResult(
            processedText: processed,
            rawText: request.text,
            appliedStages: [.grammarCorrection],
            providerID: id,
            processingTime: 0.01
        )
    }

    public func isAvailable() async -> Bool {
        lock.withLock { _available }
    }

    /// Update the transform function.
    public func setTransform(_ transform: @escaping @Sendable (String) -> String) {
        lock.withLock { _transform = transform }
    }

    /// Update availability.
    public func setAvailable(_ available: Bool) {
        lock.withLock { _available = available }
    }

    /// Update failure mode.
    public func setShouldFail(_ shouldFail: Bool) {
        lock.withLock { _shouldFail = shouldFail }
    }
}
