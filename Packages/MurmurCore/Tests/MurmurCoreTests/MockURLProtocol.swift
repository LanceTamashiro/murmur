import Foundation

/// A mock URL protocol for testing HTTP-based providers without hitting real APIs.
///
/// Uses a URL-based routing scheme: each test registers a unique endpoint URL
/// with a response, avoiding global shared state conflicts.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [URL: (Data, HTTPURLResponse)] = [:]
    nonisolated(unsafe) private static var capturedRequests: [URL: URLRequest] = [:]

    /// Register a canned response for a specific URL.
    static func register(url: URL, data: Data, statusCode: Int = 200) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        lock.lock()
        responses[url] = (data, response)
        lock.unlock()
    }

    /// Register a JSON string response for a specific URL.
    static func registerJSON(url: URL, json: String, statusCode: Int = 200) {
        register(url: url, data: json.data(using: .utf8)!, statusCode: statusCode)
    }

    /// Get the captured request for a URL (for verifying headers, body, etc.).
    static func capturedRequest(for url: URL) -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests[url]
    }

    /// Clear all registered responses and captured requests.
    static func reset() {
        lock.lock()
        responses.removeAll()
        capturedRequests.removeAll()
        lock.unlock()
    }

    /// Create a URLSession that uses this mock protocol.
    static func testSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // Capture the request (read body from stream if needed)
        var enrichedRequest = request
        if enrichedRequest.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 4096)
                if read > 0 { data.append(buffer, count: read) }
                else { break }
            }
            stream.close()
            enrichedRequest.httpBody = data
        }

        Self.lock.lock()
        Self.capturedRequests[url] = enrichedRequest
        let response = Self.responses[url]
        Self.lock.unlock()

        if let (data, httpResponse) = response {
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable)
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
