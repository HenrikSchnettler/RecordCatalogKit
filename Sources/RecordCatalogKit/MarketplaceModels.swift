import Foundation

public struct Seller: Decodable, Sendable, Equatable {
    public let id: Int?
    public let username: String
    public let resourceURL: URL?
    public let avatarURL: URL?
    public let shipping: String?
    public let payment: String?
    public let statistics: SellerStatistics?

    enum CodingKeys: String, CodingKey {
        case id, username, shipping, payment
        case resourceURL = "resource_url"
        case avatarURL = "avatar_url"
        case statistics = "stats"
    }
}

public struct SellerStatistics: Decodable, Sendable, Equatable {
    public let rating: String?
    public let stars: Double?
    public let total: Int?
}

public struct MarketplaceRelease: Decodable, Sendable, Identifiable {
    public let id: ReleaseID
    public let title: String
    public let artist: String?
    public let description: String?
    public let year: Int?
    public let format: String?
    public let catalogNumber: String?
    public let resourceURL: URL?
    public let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, description, year, format
        case catalogNumber = "catalog_number"
        case resourceURL = "resource_url"
        case thumbnailURL = "thumbnail"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ReleaseID(c.decode(Int.self, forKey: .id))
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        artist = try c.decodeIfPresent(String.self, forKey: .artist)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        year = (try? c.decode(FlexibleInt.self, forKey: .year))?.value
        format = try c.decodeIfPresent(String.self, forKey: .format)
        catalogNumber = try c.decodeIfPresent(String.self, forKey: .catalogNumber)
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        thumbnailURL = try? c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
    }
}

public struct MarketplaceListing: Decodable, Sendable, Identifiable {
    public let id: ListingID
    public let status: ListingStatus
    public let condition: MediaCondition
    public let sleeveCondition: SleeveCondition?
    public let price: Money
    public let originalPrice: Money?
    public let shippingPrice: Money?
    public let allowOffers: Bool
    public let comments: String?
    public let location: String?
    public let externalID: String?
    public let audio: Bool?
    public let posted: Date?
    public let shipsFrom: String?
    public let seller: Seller?
    public let release: MarketplaceRelease
    public let resourceURL: URL?
    public let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, status, condition, price, comments, location, posted, seller, release, audio
        case externalID = "external_id"
        case sleeveCondition = "sleeve_condition"
        case originalPrice = "original_price"
        case shippingPrice = "shipping_price"
        case allowOffers = "allow_offers"
        case shipsFrom = "ships_from"
        case resourceURL = "resource_url"
        case webURL = "uri"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ListingID(c.decode(Int.self, forKey: .id))
        status = try ListingStatus(c.decode(String.self, forKey: .status))
        condition = try MediaCondition(c.decode(String.self, forKey: .condition))
        sleeveCondition = try c.decodeIfPresent(String.self, forKey: .sleeveCondition).map(SleeveCondition.init)
        price = try c.decode(Money.self, forKey: .price)
        originalPrice = try? c.decodeIfPresent(Money.self, forKey: .originalPrice)
        shippingPrice = try? c.decodeIfPresent(Money.self, forKey: .shippingPrice)
        allowOffers = try c.decodeIfPresent(Bool.self, forKey: .allowOffers) ?? false
        comments = try c.decodeIfPresent(String.self, forKey: .comments)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        externalID = try c.decodeIfPresent(String.self, forKey: .externalID)
        audio = try c.decodeIfPresent(Bool.self, forKey: .audio)
        posted = try c.decodeIfPresent(Date.self, forKey: .posted)
        shipsFrom = try c.decodeIfPresent(String.self, forKey: .shipsFrom)
        seller = try c.decodeIfPresent(Seller.self, forKey: .seller)
        release = try c.decode(MarketplaceRelease.self, forKey: .release)
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        webURL = try? c.decodeIfPresent(URL.self, forKey: .webURL)
    }
}

public struct ListingDraft: Encodable, Sendable {
    public let releaseID: ReleaseID
    public let condition: MediaCondition
    public var sleeveCondition: SleeveCondition?
    public let price: Decimal
    public var comments: String?
    public var allowOffers: Bool?
    public var status: ListingStatus?
    public var externalID: String?
    public var location: String?
    public var weight: Int?
    public var formatQuantity: Int?

    public init(
        releaseID: ReleaseID,
        condition: MediaCondition,
        price: Decimal,
        sleeveCondition: SleeveCondition? = nil,
        comments: String? = nil,
        allowOffers: Bool? = nil,
        status: ListingStatus? = nil,
        externalID: String? = nil,
        location: String? = nil,
        weight: Int? = nil,
        formatQuantity: Int? = nil
    ) {
        self.releaseID = releaseID; self.condition = condition; self.price = price
        self.sleeveCondition = sleeveCondition; self.comments = comments; self.allowOffers = allowOffers
        self.status = status; self.externalID = externalID; self.location = location
        self.weight = weight; self.formatQuantity = formatQuantity
    }

    enum CodingKeys: String, CodingKey {
        case condition, price, comments, status, location, weight
        case releaseID = "release_id"
        case sleeveCondition = "sleeve_condition"
        case allowOffers = "allow_offers"
        case externalID = "external_id"
        case formatQuantity = "format_quantity"
    }
}

public struct ListingChanges: Encodable, Sendable {
    public var condition: MediaCondition?
    public var sleeveCondition: SleeveCondition?
    public var price: Decimal?
    public var comments: String?
    public var allowOffers: Bool?
    public var status: ListingStatus?
    public var externalID: String?
    public var location: String?
    public var weight: Int?
    public var formatQuantity: Int?

    public init(
        condition: MediaCondition? = nil,
        sleeveCondition: SleeveCondition? = nil,
        price: Decimal? = nil,
        comments: String? = nil,
        allowOffers: Bool? = nil,
        status: ListingStatus? = nil,
        externalID: String? = nil,
        location: String? = nil,
        weight: Int? = nil,
        formatQuantity: Int? = nil
    ) {
        self.condition = condition; self.sleeveCondition = sleeveCondition; self.price = price
        self.comments = comments; self.allowOffers = allowOffers; self.status = status
        self.externalID = externalID; self.location = location; self.weight = weight; self
            .formatQuantity = formatQuantity
    }

    enum CodingKeys: String, CodingKey {
        case condition, price, comments, status, location, weight
        case sleeveCondition = "sleeve_condition"
        case allowOffers = "allow_offers"
        case externalID = "external_id"
        case formatQuantity = "format_quantity"
    }
}

public struct CreatedListing: Decodable, Sendable {
    public let listingID: ListingID
    public let resourceURL: URL?
    enum CodingKeys: String, CodingKey { case listingID = "listing_id"; case resourceURL = "resource_url" }
}

public struct OrderParty: Decodable, Sendable, Equatable {
    public let id: Int?
    public let username: String
    public let resourceURL: URL?
    enum CodingKeys: String, CodingKey { case id, username; case resourceURL = "resource_url" }
}

public struct OrderItem: Decodable, Sendable, Identifiable {
    public let id: ListingID
    public let release: MarketplaceRelease
    public let price: Money
    public let mediaCondition: MediaCondition?
    public let sleeveCondition: SleeveCondition?

    enum CodingKeys: String, CodingKey {
        case id, release, price
        case mediaCondition = "media_condition"
        case sleeveCondition = "sleeve_condition"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ListingID(c.decode(Int.self, forKey: .id))
        release = try c.decode(MarketplaceRelease.self, forKey: .release)
        price = try c.decode(Money.self, forKey: .price)
        mediaCondition = try c.decodeIfPresent(String.self, forKey: .mediaCondition).map(MediaCondition.init)
        sleeveCondition = try c.decodeIfPresent(String.self, forKey: .sleeveCondition).map(SleeveCondition.init)
    }
}

public struct MarketplaceOrder: Decodable, Sendable, Identifiable {
    public let id: OrderID
    public let status: OrderStatus
    public let nextStatuses: [OrderStatus]
    public let fee: Money?
    public let shipping: OrderShipping?
    public let total: Money?
    public let tracking: OrderTracking?
    public let created: Date?
    public let lastActivity: Date?
    public let items: [OrderItem]
    public let shippingAddress: String?
    public let additionalInstructions: String?
    public let archived: Bool?
    public let seller: OrderParty?
    public let buyer: OrderParty?
    public let resourceURL: URL?
    public let messagesURL: URL?
    public let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, status, fee, shipping, total, tracking, created, items, archived, seller, buyer
        case nextStatuses = "next_status"
        case lastActivity = "last_activity"
        case shippingAddress = "shipping_address"
        case additionalInstructions = "additional_instructions"
        case resourceURL = "resource_url"
        case messagesURL = "messages_url"
        case webURL = "uri"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try OrderID(c.decode(String.self, forKey: .id))
        status = try OrderStatus(c.decode(String.self, forKey: .status))
        nextStatuses = try c.decodeIfPresent([String].self, forKey: .nextStatuses)?.map(OrderStatus.init) ?? []
        fee = try c.decodeIfPresent(Money.self, forKey: .fee)
        shipping = try c.decodeIfPresent(OrderShipping.self, forKey: .shipping)
        total = try c.decodeIfPresent(Money.self, forKey: .total)
        tracking = try c.decodeIfPresent(OrderTracking.self, forKey: .tracking)
        created = try c.decodeIfPresent(Date.self, forKey: .created)
        lastActivity = try c.decodeIfPresent(Date.self, forKey: .lastActivity)
        items = try c.decodeIfPresent([OrderItem].self, forKey: .items) ?? []
        shippingAddress = try c.decodeIfPresent(String.self, forKey: .shippingAddress)
        additionalInstructions = try c.decodeIfPresent(String.self, forKey: .additionalInstructions)
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived)
        seller = try c.decodeIfPresent(OrderParty.self, forKey: .seller)
        buyer = try c.decodeIfPresent(OrderParty.self, forKey: .buyer)
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        messagesURL = try? c.decodeIfPresent(URL.self, forKey: .messagesURL)
        webURL = try? c.decodeIfPresent(URL.self, forKey: .webURL)
    }
}

public struct OrderShipping: Decodable, Sendable, Equatable {
    public let currency: Currency
    public let value: Decimal
    public let method: String?
}

public struct OrderTracking: Decodable, Sendable, Equatable {
    public let number: String?
    public let carrier: String?
    public let url: URL?
}

public struct OrderChanges: Encodable, Sendable {
    public var status: OrderStatus?
    public var shipping: Decimal?

    public init(status: OrderStatus? = nil, shipping: Decimal? = nil) {
        self.status = status; self.shipping = shipping
    }
}

public struct OrderMessage: Decodable, Sendable {
    public let timestamp: Date?
    public let message: String?
    public let subject: String?
    public let type: String?
    public let from: OrderParty?
    public let orderID: OrderID?

    enum CodingKeys: String, CodingKey { case timestamp, message, subject, type, from, order }
    enum OrderKeys: String, CodingKey { case id }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try c.decodeIfPresent(Date.self, forKey: .timestamp)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        subject = try c.decodeIfPresent(String.self, forKey: .subject)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        from = try c.decodeIfPresent(OrderParty.self, forKey: .from)
        if let nested = try? c.nestedContainer(keyedBy: OrderKeys.self, forKey: .order),
           let id = try nested.decodeIfPresent(
               String.self,
               forKey: .id
           )
        {
            orderID = OrderID(id)
        } else {
            orderID = nil
        }
    }
}

public struct PriceSuggestions: Sendable, Decodable {
    public let values: [MediaCondition: Money]
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        var values: [MediaCondition: Money] = [:]
        for key in c.allKeys {
            values[MediaCondition(key.stringValue)] = try c.decode(Money.self, forKey: key)
        }
        self.values = values
    }
}

public struct MarketplaceStatistics: Decodable, Sendable {
    public let lowestPrice: Money?
    public let numberForSale: Int?
    public let blockedFromSale: Bool
    enum CodingKeys: String,
        CodingKey
    {
        case lowestPrice = "lowest_price"; case numberForSale = "num_for_sale"; case blockedFromSale =
            "blocked_from_sale"
    }
}
