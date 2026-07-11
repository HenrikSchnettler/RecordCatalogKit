import Foundation

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw RecordCatalogError.invalidResponse
        }
        return (data, response)
    }
}

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum AuthenticationRequirement: Sendable, Equatable {
    case none
    case optional
    case authenticated
    case user
}

enum RequestBody: Sendable {
    case none
    case json(Data)
    case form([URLQueryItem])
    case raw(Data, contentType: String)
}

struct Endpoint<Response: Decodable & Sendable>: Sendable {
    var method: HTTPMethod
    var path: String
    var query: [URLQueryItem]
    var body: RequestBody
    var authentication: AuthenticationRequirement

    static func get(
        _ path: String,
        query: [URLQueryItem] = [],
        authentication: AuthenticationRequirement = .optional
    ) -> Self {
        Endpoint(method: .get, path: path, query: query, body: .none, authentication: authentication)
    }

    static func request(
        _ method: HTTPMethod,
        _ path: String,
        query: [URLQueryItem] = [],
        body: RequestBody = .none,
        authentication: AuthenticationRequirement = .user
    ) -> Self {
        Endpoint(method: method, path: path, query: query, body: body, authentication: authentication)
    }
}

actor ClientCore {
    private let baseURL = URL(string: "https://api.discogs.com")!
    private let configuration: RecordCatalogConfiguration
    private let transport: any HTTPTransport
    private let rateLimits = RateLimitState()
    private let decoder: JSONDecoder

    init(configuration: RecordCatalogConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
        decoder = JSONDecoder.recordCatalog
    }

    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = try makeRequest(endpoint)
        let data = try await perform(request, method: endpoint.method).data
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw RecordCatalogError.decoding(
                endpoint: endpoint.path,
                description: Self.safeDecodingDescription(error)
            )
        }
    }

    func sendVoid(_ endpoint: Endpoint<EmptyResponse>) async throws {
        let request = try makeRequest(endpoint)
        _ = try await perform(request, method: endpoint.method)
    }

    func sendData(_ endpoint: RawEndpoint) async throws -> Data {
        let request = try makeRequest(endpoint)
        return try await perform(request, method: endpoint.method).data
    }

    func sendRaw(_ endpoint: RawEndpoint) async throws -> RawHTTPResponse {
        let request = try makeRequest(endpoint)
        return try await perform(request, method: endpoint.method)
    }

    func rateLimitStatus() async -> RateLimitStatus? {
        await rateLimits.current
    }

    private func makeRequest(_ endpoint: Endpoint<some Any>) throws -> URLRequest {
        try validateAuthentication(endpoint.authentication)
        return try makeRequest(
            method: endpoint.method,
            path: endpoint.path,
            query: endpoint.query,
            body: endpoint.body,
            authentication: endpoint.authentication
        )
    }

    private func makeRequest(_ endpoint: RawEndpoint) throws -> URLRequest {
        try validateAuthentication(endpoint.authentication)
        if let absoluteURL = endpoint.absoluteURL {
            guard absoluteURL.scheme?.lowercased() == "https",
                  let host = absoluteURL.host?.lowercased(),
                  host == "discogs.com" || host.hasSuffix(".discogs.com")
            else {
                throw RecordCatalogError.invalidRequest("Only HTTPS Discogs URLs may be downloaded.")
            }
            return try makeRequest(
                method: endpoint.method,
                absoluteURL: absoluteURL,
                query: endpoint.query,
                body: endpoint.body,
                authentication: endpoint.authentication
            )
        }
        return try makeRequest(
            method: endpoint.method,
            path: endpoint.path,
            query: endpoint.query,
            body: endpoint.body,
            authentication: endpoint.authentication
        )
    }

    private func makeRequest(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem],
        body: RequestBody,
        authentication: AuthenticationRequirement
    ) throws -> URLRequest {
        guard path.hasPrefix("/") else {
            throw RecordCatalogError.invalidRequest("Endpoint paths must begin with '/'.")
        }
        let url = baseURL.appending(path: String(path.dropFirst()))
        return try makeRequest(
            method: method,
            absoluteURL: url,
            query: query,
            body: body,
            authentication: authentication
        )
    }

    private func makeRequest(
        method: HTTPMethod,
        absoluteURL: URL,
        query: [URLQueryItem],
        body: RequestBody,
        authentication: AuthenticationRequirement
    ) throws -> URLRequest {
        guard var components = URLComponents(url: absoluteURL, resolvingAgainstBaseURL: false) else {
            throw RecordCatalogError.invalidRequest("The endpoint URL is invalid.")
        }
        if !query.isEmpty {
            components.queryItems = (components.queryItems ?? []) + query
        }
        guard let url = components.url else {
            throw RecordCatalogError.invalidRequest("The endpoint query could not be encoded.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(configuration.responseFormat.acceptHeader, forHTTPHeaderField: "Accept")
        applyAuthentication(to: &request, requirement: authentication)
        switch body {
        case .none:
            break
        case let .json(data):
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case let .form(items):
            var form = URLComponents()
            form.queryItems = items
            request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        case let .raw(data, contentType):
            request.httpBody = data
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func perform(_ request: URLRequest, method: HTTPMethod) async throws -> RawHTTPResponse {
        do { try await rateLimits.waitIfNeeded() }
        catch is CancellationError { throw RecordCatalogError.cancelled }
        let policy = configuration.retryPolicy
        var attempt = 0
        while true {
            do {
                let (data, response) = try await transport.data(for: request)
                let status = await rateLimits.update(from: response)
                if (200 ..< 300).contains(response.statusCode) {
                    return RawHTTPResponse(data: data, response: response)
                }

                let message = Self.decodeMessage(from: data)
                if response.statusCode == 429 {
                    let retryAfter = Self.retryAfter(from: response)
                    if method == .get, attempt < policy.maximumRetryCount {
                        try await sleep(attempt: attempt, retryAfter: retryAfter)
                        attempt += 1
                        continue
                    }
                    throw RecordCatalogError.rateLimited(retryAfter: retryAfter, status: status)
                }
                if method == .get,
                   [500, 502, 503, 504].contains(response.statusCode),
                   attempt < policy.maximumRetryCount
                {
                    try await sleep(attempt: attempt, retryAfter: nil)
                    attempt += 1
                    continue
                }
                throw RecordCatalogError.api(
                    APIError(statusCode: response.statusCode, message: message, rateLimit: status)
                )
            } catch is CancellationError {
                throw RecordCatalogError.cancelled
            } catch let error as RecordCatalogError {
                throw error
            } catch let error as URLError {
                if method == .get, attempt < policy.maximumRetryCount, Self.isRetryable(error) {
                    try await sleep(attempt: attempt, retryAfter: nil)
                    attempt += 1
                    continue
                }
                throw RecordCatalogError.transport(code: error.code, description: error.localizedDescription)
            } catch {
                throw RecordCatalogError.transport(code: .unknown, description: error.localizedDescription)
            }
        }
    }

    private func sleep(attempt: Int, retryAfter: Duration?) async throws {
        if let retryAfter {
            try await Task.sleep(for: retryAfter)
            return
        }
        let exponent = pow(2.0, Double(attempt))
        let base = configuration.retryPolicy.initialDelay.timeInterval * exponent
        let maximum = configuration.retryPolicy.maximumDelay.timeInterval
        let jitter = Double.random(in: 0.8 ... 1.2)
        try await Task.sleep(for: .seconds(min(maximum, base * jitter)))
    }

    private func validateAuthentication(_ requirement: AuthenticationRequirement) throws {
        switch (requirement, configuration.authentication) {
        case (.none, _), (.optional, _), (.authenticated, .consumerCredentials),
             (.authenticated, .personalToken), (.authenticated, .oauth),
             (.user, .personalToken), (.user, .oauth):
            break
        case (.authenticated, .anonymous):
            throw RecordCatalogError.authenticationRequired
        case (.user, .anonymous):
            throw RecordCatalogError.authenticationRequired
        case (.user, .consumerCredentials):
            throw RecordCatalogError.insufficientAuthentication
        }
    }

    private func applyAuthentication(to request: inout URLRequest, requirement: AuthenticationRequirement) {
        guard requirement != .none else { return }
        switch configuration.authentication {
        case .anonymous:
            break
        case let .consumerCredentials(credentials):
            request.setValue(
                "Discogs key=\(credentials.key), secret=\(credentials.secret)",
                forHTTPHeaderField: "Authorization"
            )
        case let .personalToken(token):
            request.setValue("Discogs token=\(token.value)", forHTTPHeaderField: "Authorization")
        case let .oauth(consumer, access):
            request.setValue(
                OAuthSigner.authorizationHeader(
                    consumer: consumer,
                    token: access.token,
                    tokenSecret: access.secret
                ),
                forHTTPHeaderField: "Authorization"
            )
        }
    }

    private static func decodeMessage(from data: Data) -> String? {
        struct Message: Decodable { let message: String? }
        return (try? JSONDecoder().decode(Message.self, from: data))?.message
    }

    private static func retryAfter(from response: HTTPURLResponse) -> Duration? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Double(value) else { return nil }
        return .seconds(seconds)
    }

    private static func isRetryable(_ error: URLError) -> Bool {
        [
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .dnsLookupFailed,
            .notConnectedToInternet,
        ].contains(error.code)
    }

    private static func safeDecodingDescription(_ error: Error) -> String {
        switch error {
        case let DecodingError.keyNotFound(key, context):
            "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))."
        case let DecodingError.typeMismatch(_, context),
             let DecodingError.valueNotFound(_, context),
             let DecodingError.dataCorrupted(context):
            "\(context.debugDescription) at \(context.codingPath.map(\.stringValue).joined(separator: "."))."
        default:
            String(describing: error)
        }
    }
}

struct RawEndpoint: Sendable {
    var method: HTTPMethod = .get
    var path: String = ""
    var absoluteURL: URL?
    var query: [URLQueryItem] = []
    var body: RequestBody = .none
    var authentication: AuthenticationRequirement = .optional
}

struct RawHTTPResponse: Sendable {
    let data: Data
    let response: HTTPURLResponse
}

struct EmptyResponse: Decodable, Sendable {}

public struct RateLimitStatus: Sendable, Equatable, Codable {
    public let limit: Int
    public let used: Int
    public let remaining: Int

    public init(limit: Int, used: Int, remaining: Int) {
        self.limit = limit
        self.used = used
        self.remaining = remaining
    }
}

actor RateLimitState {
    private(set) var current: RateLimitStatus?
    private var exhaustedAt: Date?

    func update(from response: HTTPURLResponse) -> RateLimitStatus? {
        guard let limit = Self.intHeader("X-Discogs-Ratelimit", in: response),
              let used = Self.intHeader("X-Discogs-Ratelimit-Used", in: response),
              let remaining = Self.intHeader("X-Discogs-Ratelimit-Remaining", in: response)
        else {
            return current
        }
        let status = RateLimitStatus(limit: limit, used: used, remaining: remaining)
        current = status
        exhaustedAt = remaining == 0 ? Date() : nil
        return status
    }

    func waitIfNeeded() async throws {
        guard current?.remaining == 0, let exhaustedAt else { return }
        let elapsed = Date().timeIntervalSince(exhaustedAt)
        if elapsed < 60 {
            try await Task.sleep(for: .seconds(60 - elapsed))
        }
        current = nil
        self.exhaustedAt = nil
    }

    private static func intHeader(_ name: String, in response: HTTPURLResponse) -> Int? {
        response.value(forHTTPHeaderField: name).flatMap(Int.init)
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let components = components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

extension JSONDecoder {
    static var recordCatalog: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = parseISO8601(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 timestamp: \(string)"
            )
        }
        return decoder
    }
}

private func parseISO8601(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) {
        return date
    }
    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    if let date = standard.date(from: value) {
        return date
    }
    let withoutZone = DateFormatter()
    withoutZone.locale = Locale(identifier: "en_US_POSIX")
    withoutZone.calendar = Calendar(identifier: .gregorian)
    withoutZone.timeZone = TimeZone(secondsFromGMT: 0)
    withoutZone.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return withoutZone.date(from: value)
}

func jsonBody(_ value: some Encodable) throws -> RequestBody {
    do { return try .json(JSONEncoder().encode(value)) }
    catch { throw RecordCatalogError.invalidRequest("The request body could not be encoded: \(error)") }
}

func escapedPath(_ value: String) throws -> String {
    guard !value.isEmpty,
          let escaped = value.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed),
          !escaped.contains("/")
    else {
        throw RecordCatalogError.invalidRequest("A path identifier is empty or invalid.")
    }
    return escaped
}

private extension CharacterSet {
    static let urlPathComponentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/?#")
        return set
    }()
}
