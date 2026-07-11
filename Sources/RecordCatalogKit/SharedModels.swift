import Foundation

public protocol IntegerDiscogsID: RawRepresentable, Codable, Hashable, Sendable where RawValue == Int {
    init(rawValue: Int)
}

public extension IntegerDiscogsID {
    init(_ rawValue: Int) {
        self.init(rawValue: rawValue)
    }
}

public struct ReleaseID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct MasterID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct ArtistID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct LabelID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct ListingID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct FolderID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct CollectionInstanceID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct CustomFieldID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct ExportID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct UploadID: IntegerDiscogsID {
    public let rawValue: Int; public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct OrderID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// A forward-compatible string value. Known values are exposed as static constants.
public protocol ExtensibleStringValue: RawRepresentable, Codable, Hashable, Sendable where RawValue == String {
    init(rawValue: String)
}

public extension ExtensibleStringValue {
    init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}

public struct Currency: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let usd = Self("USD"), gbp = Self("GBP"), eur = Self("EUR")
    public static let cad = Self("CAD"), aud = Self("AUD"), jpy = Self("JPY")
    public static let chf = Self("CHF"), mxn = Self("MXN"), brl = Self("BRL")
    public static let nzd = Self("NZD"), sek = Self("SEK"), zar = Self("ZAR")
}

public struct MediaCondition: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let mint = Self("Mint (M)")
    public static let nearMint = Self("Near Mint (NM or M-)")
    public static let veryGoodPlus = Self("Very Good Plus (VG+)")
    public static let veryGood = Self("Very Good (VG)")
    public static let goodPlus = Self("Good Plus (G+)")
    public static let good = Self("Good (G)")
    public static let fair = Self("Fair (F)")
    public static let poor = Self("Poor (P)")
}

public struct SleeveCondition: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let generic = Self("Generic")
    public static let notGraded = Self("Not Graded")
    public static let noCover = Self("No Cover")
    public static let mint = Self("Mint (M)")
    public static let nearMint = Self("Near Mint (NM or M-)")
    public static let veryGoodPlus = Self("Very Good Plus (VG+)")
    public static let veryGood = Self("Very Good (VG)")
    public static let goodPlus = Self("Good Plus (G+)")
    public static let good = Self("Good (G)")
    public static let fair = Self("Fair (F)")
    public static let poor = Self("Poor (P)")
}

public struct ListingStatus: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let forSale = Self("For Sale"), sold = Self("Sold"), draft = Self("Draft")
    public static let expired = Self("Expired"), suspended = Self("Suspended"), deleted = Self("Deleted")
}

public struct OrderStatus: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let newOrder = Self("New Order")
    public static let buyerContacted = Self("Buyer Contacted")
    public static let invoiceSent = Self("Invoice Sent")
    public static let paymentPending = Self("Payment Pending")
    public static let paymentReceived = Self("Payment Received")
    public static let inProgress = Self("In Progress")
    public static let shipped = Self("Shipped")
    public static let refundSent = Self("Refund Sent")
}

public struct Money: Sendable, Equatable, Decodable {
    public let currency: Currency
    public let value: Decimal

    enum CodingKeys: String, CodingKey { case currency, currencyAbbreviation = "curr_abbr", value }

    public init(currency: Currency, value: Decimal) {
        self.currency = currency
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawCurrency = try c.decodeIfPresent(String.self, forKey: .currency)
            ?? c.decode(String.self, forKey: .currencyAbbreviation)
        currency = Currency(rawCurrency)
        if let decimal = try? c.decode(Decimal.self, forKey: .value) {
            value = decimal
        } else {
            let string = try c.decode(String.self, forKey: .value)
            guard let decimal = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value,
                    in: c,
                    debugDescription: "Invalid decimal money value"
                )
            }
            value = decimal
        }
    }
}

public struct ResourceReference<ID: RawRepresentable & Decodable & Sendable>: Decodable,
    Sendable where ID.RawValue: Decodable & Sendable
{
    public let id: ID
    public let resourceURL: URL?

    enum CodingKeys: String, CodingKey { case id; case resourceURL = "resource_url" }
}

public struct ImageResource: Decodable, Sendable, Equatable {
    public let type: String?
    public let width: Int?
    public let height: Int?
    public let resourceURL: URL?
    public let uri: URL?
    public let uri150: URL?

    enum CodingKeys: String, CodingKey {
        case type, width, height, uri
        case resourceURL = "resource_url"
        case uri150
    }
}

public struct DownloadedImage: Sendable {
    public let data: Data
    public let contentType: String?
}

public struct ReleaseDate: Sendable, Equatable, Codable, CustomStringConvertible {
    public let rawValue: String
    public var description: String {
        rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var components: DateComponents? {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard let year = parts.first else { return nil }
        var components = DateComponents()
        components.year = year
        if parts.count > 1 {
            components.month = parts[1]
        }
        if parts.count > 2 {
            components.day = parts[2]
        }
        return components
    }
}

public enum JSONValue: Sendable, Equatable, Codable {
    case string(String)
    case number(Decimal)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public enum UpdateField<Value: Sendable>: Sendable {
    case unchanged
    case set(Value)
    case clear
}

struct FlexibleInt: Decodable, Sendable {
    let value: Int
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int; return
        }
        if let string = try? container.decode(String.self), let int = Int(string) {
            value = int; return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected an integer or numeric string")
    }
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
    }
}

func query(_ name: String, _ value: String?) -> URLQueryItem? {
    value.map { URLQueryItem(name: name, value: $0) }
}

func query(_ name: String, _ value: Int?) -> URLQueryItem? {
    value.map { URLQueryItem(name: name, value: String($0)) }
}

func query(_ name: String, _ value: Bool?) -> URLQueryItem? {
    value.map { URLQueryItem(name: name, value: $0 ? "true" : "false") }
}
