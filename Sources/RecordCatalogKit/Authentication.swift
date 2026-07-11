import Foundation

public enum Authentication: Sendable {
    case anonymous
    case consumerCredentials(ConsumerCredentials)
    case personalToken(PersonalToken)
    case oauth(consumer: ConsumerCredentials, access: OAuthAccessCredentials)

    public static func consumerCredentials(key: String, secret: String) -> Self {
        .consumerCredentials(ConsumerCredentials(key: key, secret: secret))
    }

    public static func personalToken(_ value: String) -> Self {
        .personalToken(PersonalToken(value))
    }
}

extension Authentication: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .anonymous: "anonymous"
        case .consumerCredentials: "consumerCredentials(<redacted>)"
        case .personalToken: "personalToken(<redacted>)"
        case .oauth: "oauth(<redacted>)"
        }
    }

    public var debugDescription: String {
        description
    }
}

public struct ConsumerCredentials: Sendable {
    public let key: String
    let secret: String

    public init(key: String, secret: String) {
        self.key = key
        self.secret = secret
    }
}

extension ConsumerCredentials: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "ConsumerCredentials(key: \(key), secret: <redacted>)"
    }

    public var debugDescription: String {
        description
    }
}

public struct PersonalToken: Sendable {
    let value: String

    public init(_ value: String) {
        self.value = value
    }
}

extension PersonalToken: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "PersonalToken(<redacted>)"
    }

    public var debugDescription: String {
        description
    }
}

public struct OAuthAccessCredentials: Sendable {
    public let token: String
    /// The OAuth token secret. Treat this as sensitive and persist it only in secure storage.
    public let secret: String

    public init(token: String, secret: String) {
        self.token = token
        self.secret = secret
    }
}

extension OAuthAccessCredentials: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "OAuthAccessCredentials(token: <redacted>, secret: <redacted>)"
    }

    public var debugDescription: String {
        description
    }
}

public struct OAuthRequestToken: Sendable {
    public let token: String
    let secret: String
}

public struct OAuthAuthorizationRequest: Sendable {
    public let requestToken: OAuthRequestToken
    public let authorizationURL: URL
}

public enum OAuthCallback: Sendable {
    case url(URL)
    case outOfBand

    var value: String {
        switch self {
        case let .url(url): url.absoluteString
        case .outOfBand: "oob"
        }
    }
}

/// Performs the user-facing OAuth 1.0a token exchange without presenting UI or storing secrets.
public struct OAuthCoordinator: Sendable {
    private let consumer: ConsumerCredentials
    private let userAgent: String
    private let transport: any HTTPTransport

    public init(
        consumer: ConsumerCredentials,
        userAgent: String,
        session: URLSession = .shared
    ) {
        self.consumer = consumer
        self.userAgent = userAgent
        transport = URLSessionTransport(session: session)
    }

    init(consumer: ConsumerCredentials, userAgent: String, transport: any HTTPTransport) {
        self.consumer = consumer
        self.userAgent = userAgent
        self.transport = transport
    }

    public func requestAuthorization(callback: OAuthCallback) async throws -> OAuthAuthorizationRequest {
        var request = URLRequest(url: URL(string: "https://api.discogs.com/oauth/request_token")!)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(
            OAuthSigner.authorizationHeader(consumer: consumer, callback: callback.value),
            forHTTPHeaderField: "Authorization"
        )
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        let values = Self.formValues(data)
        guard let token = values["oauth_token"], let secret = values["oauth_token_secret"] else {
            throw RecordCatalogError.oauth("Discogs did not return a request token and secret.")
        }
        let requestToken = OAuthRequestToken(token: token, secret: secret)
        var components = URLComponents(string: "https://www.discogs.com/oauth/authorize")!
        components.queryItems = [URLQueryItem(name: "oauth_token", value: token)]
        return OAuthAuthorizationRequest(requestToken: requestToken, authorizationURL: components.url!)
    }

    public func exchange(
        _ requestToken: OAuthRequestToken,
        verifier: String
    ) async throws -> OAuthAccessCredentials {
        var request = URLRequest(url: URL(string: "https://api.discogs.com/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(
            OAuthSigner.authorizationHeader(
                consumer: consumer,
                token: requestToken.token,
                tokenSecret: requestToken.secret,
                verifier: verifier
            ),
            forHTTPHeaderField: "Authorization"
        )
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        let values = Self.formValues(data)
        guard let token = values["oauth_token"], let secret = values["oauth_token_secret"] else {
            throw RecordCatalogError.oauth("Discogs did not return access credentials.")
        }
        return OAuthAccessCredentials(token: token, secret: secret)
    }

    private static func validate(response: HTTPURLResponse, data: Data) throws {
        guard (200 ..< 300).contains(response.statusCode) else {
            throw RecordCatalogError.api(
                APIError(
                    statusCode: response.statusCode,
                    message: "Discogs OAuth returned HTTP \(response.statusCode).",
                    rateLimit: nil
                )
            )
        }
    }

    private static func formValues(_ data: Data) -> [String: String] {
        guard let string = String(data: data, encoding: .utf8) else { return [:] }
        return string.split(separator: "&").reduce(into: [:]) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return }
            result[parts[0].removingPercentEncoding ?? parts[0]] =
                parts[1].removingPercentEncoding ?? parts[1]
        }
    }
}

enum OAuthSigner {
    static func authorizationHeader(
        consumer: ConsumerCredentials,
        token: String? = nil,
        tokenSecret: String = "",
        callback: String? = nil,
        verifier: String? = nil,
        nonce: String = UUID().uuidString,
        timestamp: Int = Int(Date().timeIntervalSince1970)
    ) -> String {
        var fields: [(String, String)] = [
            ("oauth_consumer_key", consumer.key),
            ("oauth_nonce", nonce),
            ("oauth_signature", "\(consumer.secret)&\(tokenSecret)"),
            ("oauth_signature_method", "PLAINTEXT"),
            ("oauth_timestamp", String(timestamp)),
        ]
        if let token {
            fields.append(("oauth_token", token))
        }
        if let callback {
            fields.append(("oauth_callback", callback))
        }
        if let verifier {
            fields.append(("oauth_verifier", verifier))
        }
        return "OAuth " + fields
            .map { "\($0.0)=\"\(percentEncode($0.1))\"" }
            .joined(separator: ", ")
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
