import Foundation

public enum RecordCatalogError: Error, Sendable {
    case invalidConfiguration(String)
    case invalidRequest(String)
    case authenticationRequired
    case insufficientAuthentication
    case oauth(String)
    case transport(code: URLError.Code, description: String)
    case rateLimited(retryAfter: Duration?, status: RateLimitStatus?)
    case api(APIError)
    case invalidResponse
    case decoding(endpoint: String, description: String)
    case file(String)
    case cancelled
}

extension RecordCatalogError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message), let .invalidRequest(message), let .oauth(message), let .file(message):
            message
        case .authenticationRequired:
            "This Discogs endpoint requires authentication."
        case .insufficientAuthentication:
            "This endpoint requires user authentication, not consumer credentials alone."
        case let .transport(_, description):
            "The request failed: \(description)"
        case .rateLimited:
            "The Discogs API rate limit was reached."
        case let .api(error):
            error.message ?? "Discogs returned HTTP \(error.statusCode)."
        case .invalidResponse:
            "Discogs returned an invalid HTTP response."
        case let .decoding(endpoint, description):
            "Could not decode \(endpoint): \(description)"
        case .cancelled:
            "The operation was cancelled."
        }
    }
}

public struct APIError: Error, Sendable {
    public let statusCode: Int
    public let message: String?
    public let rateLimit: RateLimitStatus?

    public init(statusCode: Int, message: String?, rateLimit: RateLimitStatus?) {
        self.statusCode = statusCode
        self.message = message
        self.rateLimit = rateLimit
    }
}
