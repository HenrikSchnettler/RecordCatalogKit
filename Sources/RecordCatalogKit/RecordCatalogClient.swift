import Foundation

/// An asynchronous, concurrency-safe client for the Discogs API.
public struct RecordCatalogClient: Sendable {
    let core: ClientCore

    public init(
        configuration: RecordCatalogConfiguration,
        session: URLSession = .shared
    ) throws {
        try configuration.validate()
        core = ClientCore(
            configuration: configuration,
            transport: URLSessionTransport(session: session)
        )
    }

    init(configuration: RecordCatalogConfiguration, transport: any HTTPTransport) throws {
        try configuration.validate()
        core = ClientCore(configuration: configuration, transport: transport)
    }

    public var database: DatabaseService {
        DatabaseService(core: core)
    }

    public var marketplace: MarketplaceService {
        MarketplaceService(core: core)
    }

    public var inventory: InventoryService {
        InventoryService(core: core)
    }

    public var images: ImageService {
        ImageService(core: core)
    }

    public func user(_ username: String) -> UserResource {
        UserResource(core: core, username: username)
    }

    public func identity() async throws -> UserIdentity {
        try await core.send(.get("/oauth/identity", authentication: .user))
    }

    public func latestRateLimitStatus() async -> RateLimitStatus? {
        await core.rateLimitStatus()
    }
}

public struct RecordCatalogConfiguration: Sendable {
    public var userAgent: String
    public var authentication: Authentication
    public var responseFormat: ResponseFormat
    public var retryPolicy: RetryPolicy

    public init(
        userAgent: String,
        authentication: Authentication = .anonymous,
        responseFormat: ResponseFormat = .discogs,
        retryPolicy: RetryPolicy = .default
    ) {
        self.userAgent = userAgent
        self.authentication = authentication
        self.responseFormat = responseFormat
        self.retryPolicy = retryPolicy
    }

    func validate() throws {
        let value = userAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 3, !value.contains("\n"), !value.contains("\r") else {
            throw RecordCatalogError.invalidConfiguration(
                "A unique, non-empty User-Agent without line breaks is required by Discogs."
            )
        }
    }
}

public enum ResponseFormat: String, Sendable, Codable, CaseIterable {
    case discogs
    case plainText = "plaintext"
    case html

    var acceptHeader: String {
        "application/vnd.discogs.v2.\(rawValue)+json"
    }
}

public struct RetryPolicy: Sendable, Equatable {
    public var maximumRetryCount: Int
    public var initialDelay: Duration
    public var maximumDelay: Duration

    public init(
        maximumRetryCount: Int = 2,
        initialDelay: Duration = .milliseconds(250),
        maximumDelay: Duration = .seconds(4)
    ) {
        self.maximumRetryCount = max(0, maximumRetryCount)
        self.initialDelay = initialDelay
        self.maximumDelay = maximumDelay
    }

    public static let `default` = RetryPolicy()
    public static let disabled = RetryPolicy(maximumRetryCount: 0)
}
