import Foundation

public struct MarketplaceService: Sendable {
    let core: ClientCore

    public func listing(id: ListingID, currency: Currency? = nil) async throws -> MarketplaceListing {
        try await core.send(.get(
            "/marketplace/listings/\(id.rawValue)",
            query: [query("curr_abbr", currency?.rawValue)].compactMap(\.self)
        ))
    }

    @discardableResult
    public func createListing(_ draft: ListingDraft) async throws -> CreatedListing {
        try await core.send(.request(.post, "/marketplace/listings", body: jsonBody(draft)))
    }

    @discardableResult
    public func updateListing(_ id: ListingID, changes: ListingChanges) async throws -> MarketplaceListing {
        try await core.send(.request(.post, "/marketplace/listings/\(id.rawValue)", body: jsonBody(changes)))
    }

    public func deleteListing(_ id: ListingID) async throws {
        try await core.sendVoid(.request(.delete, "/marketplace/listings/\(id.rawValue)"))
    }

    public func order(id: OrderID) async throws -> MarketplaceOrder {
        try await core.send(.get("/marketplace/orders/\(escapedPath(id.rawValue))", authentication: .user))
    }

    @discardableResult
    public func updateOrder(_ id: OrderID, changes: OrderChanges) async throws -> MarketplaceOrder {
        try await core.send(.request(
            .post,
            "/marketplace/orders/\(escapedPath(id.rawValue))",
            body: jsonBody(changes)
        ))
    }

    public func orders(filters: OrderFilters = .init(), pageSize: Int = 50) -> Paginator<MarketplaceOrder> {
        Paginator(pageSize: pageSize) { [core] page in
            let response: OrdersResponse = try await core.send(.get(
                "/marketplace/orders",
                query: page.validated().queryItems + filters.queryItems,
                authentication: .user
            ))
            return Page(items: response.orders, metadata: response.pagination)
        }
    }

    public func messages(for orderID: OrderID, pageSize: Int = 50) -> Paginator<OrderMessage> {
        Paginator(pageSize: pageSize) { [core] page in
            let response: MessagesResponse = try await core.send(.get(
                "/marketplace/orders/\(escapedPath(orderID.rawValue))/messages",
                query: page.validated().queryItems,
                authentication: .user
            ))
            return Page(items: response.messages, metadata: response.pagination)
        }
    }

    @discardableResult
    public func addMessage(_ message: String, to orderID: OrderID) async throws -> OrderMessage {
        struct Body: Encodable { let message: String }
        return try await core.send(.request(
            .post,
            "/marketplace/orders/\(escapedPath(orderID.rawValue))/messages",
            body: jsonBody(Body(message: message))
        ))
    }

    public func fee(for price: Decimal, currency: Currency? = nil) async throws -> Money {
        let path = currency.map { "/marketplace/fee/\(price)/\($0.rawValue)" } ?? "/marketplace/fee/\(price)"
        return try await core.send(.get(path))
    }

    public func priceSuggestions(for releaseID: ReleaseID) async throws -> PriceSuggestions {
        try await core.send(.get("/marketplace/price_suggestions/\(releaseID.rawValue)", authentication: .user))
    }

    public func statistics(for releaseID: ReleaseID, currency: Currency? = nil) async throws -> MarketplaceStatistics {
        try await core.send(.get(
            "/marketplace/stats/\(releaseID.rawValue)",
            query: [query("curr_abbr", currency?.rawValue)].compactMap(\.self)
        ))
    }
}

public struct OrderFilters: Sendable {
    public var status: OrderStatus?
    public var createdAfter: Date?
    public var createdBefore: Date?
    public var sort: OrderSort?
    public var order: SortOrder?

    public init(
        status: OrderStatus? = nil,
        createdAfter: Date? = nil,
        createdBefore: Date? = nil,
        sort: OrderSort? = nil,
        order: SortOrder? = nil
    ) {
        self.status = status; self.createdAfter = createdAfter; self.createdBefore = createdBefore; self
            .sort = sort; self.order = order
    }

    var queryItems: [URLQueryItem] {
        let formatter = ISO8601DateFormatter()
        return [
            query("status", status?.rawValue),
            query("created_after", createdAfter.map(formatter.string(from:))),
            query("created_before", createdBefore.map(formatter.string(from:))),
            query("sort", sort?.rawValue), query("sort_order", order?.rawValue),
        ].compactMap(\.self)
    }
}

public struct OrderSort: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let id = Self("id"), buyer = Self("buyer"), created = Self("created"), status = Self("status"),
                      lastActivity = Self("last_activity")
}

public struct InventoryFilters: Sendable {
    public var status: ListingStatus?
    public var sort: InventorySort?
    public var order: SortOrder?
    public init(status: ListingStatus? = nil, sort: InventorySort? = nil, order: SortOrder? = nil) {
        self.status = status; self.sort = sort; self.order = order
    }

    var queryItems: [URLQueryItem] {
        [
            query("status", status?.rawValue),
            query("sort", sort?.rawValue),
            query("sort_order", order?.rawValue),
        ].compactMap(\.self)
    }
}

public struct InventorySort: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let listed = Self("listed"), price = Self("price"), item = Self("item"), artist = Self("artist"),
                      label = Self("label"), catalogNumber = Self("catno"), audio = Self("audio"),
                      status = Self("status")
}

private struct OrdersResponse: Decodable, Sendable { let pagination: PageMetadata; let orders: [MarketplaceOrder] }
private struct MessagesResponse: Decodable, Sendable { let pagination: PageMetadata; let messages: [OrderMessage] }
