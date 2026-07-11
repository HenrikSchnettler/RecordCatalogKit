import Foundation

public struct UserIdentity: Decodable, Sendable, Equatable {
    public let id: Int
    public let username: String
    public let resourceURL: URL?
    public let consumerName: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case resourceURL = "resource_url"
        case consumerName = "consumer_name"
    }
}

public struct UserProfile: Decodable, Sendable, Identifiable {
    public let id: Int
    public let username: String
    public let name: String?
    public let email: String?
    public let profile: String?
    public let location: String?
    public let homePage: URL?
    public let registered: Date?
    public let currency: Currency?
    public let avatarURL: URL?
    public let bannerURL: URL?
    public let resourceURL: URL?
    public let webURL: URL?
    public let collectionFieldsURL: URL?
    public let collectionFoldersURL: URL?
    public let inventoryURL: URL?
    public let releasesContributed: Int?
    public let releasesRated: Int?
    public let ratingAverage: Double?
    public let numberForSale: Int?
    public let numberInCollection: Int?
    public let numberInWantlist: Int?

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, profile, location, registered, currency
        case homePage = "home_page"
        case avatarURL = "avatar_url"
        case bannerURL = "banner_url"
        case resourceURL = "resource_url"
        case webURL = "uri"
        case collectionFieldsURL = "collection_fields_url"
        case collectionFoldersURL = "collection_folders_url"
        case inventoryURL = "inventory_url"
        case releasesContributed = "releases_contributed"
        case releasesRated = "releases_rated"
        case ratingAverage = "rating_avg"
        case numberForSale = "num_for_sale"
        case numberInCollection = "num_collection"
        case numberInWantlist = "num_wantlist"
    }
}

public struct ProfileChanges: Encodable, Sendable {
    public var name: String?
    public var homePage: String?
    public var location: String?
    public var profile: String?
    public var currency: Currency?

    public init(
        name: String? = nil,
        homePage: String? = nil,
        location: String? = nil,
        profile: String? = nil,
        currency: Currency? = nil
    ) {
        self.name = name; self.homePage = homePage; self.location = location; self.profile = profile; self
            .currency = currency
    }

    enum CodingKeys: String, CodingKey { case name, location, profile, currency; case homePage = "home_page" }
}

public enum Submission: Sendable {
    case artist(Artist)
    case label(Label)
    case release(Release)
}

public struct Contribution: Decodable, Sendable, Identifiable {
    public let id: ReleaseID
    public let title: String
    public let status: String?
    public let artists: [ArtistCredit]
    public let resourceURL: URL?

    enum CodingKeys: String, CodingKey { case id, title, status, artists; case resourceURL = "resource_url" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ReleaseID(c.decode(Int.self, forKey: .id))
        title = try c.decode(String.self, forKey: .title)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        artists = try c.decodeIfPresent([ArtistCredit].self, forKey: .artists) ?? []
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
    }
}

public struct CollectionFolder: Decodable, Sendable, Equatable, Identifiable {
    public let id: FolderID
    public let name: String
    public let count: Int
    public let resourceURL: URL?

    enum CodingKeys: String, CodingKey { case id, name, count; case resourceURL = "resource_url" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try FolderID(c.decode(Int.self, forKey: .id))
        name = try c.decode(String.self, forKey: .name)
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
    }
}

public struct BasicRelease: Decodable, Sendable, Identifiable {
    public let id: ReleaseID
    public let title: String
    public let year: Int?
    public let artists: [ArtistCredit]
    public let formats: [ReleaseFormat]
    public let labels: [ReleaseLabel]
    public let resourceURL: URL?
    public let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, year, artists, formats, labels
        case resourceURL = "resource_url"
        case thumbnailURL = "thumb"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ReleaseID(c.decode(Int.self, forKey: .id))
        title = try c.decode(String.self, forKey: .title)
        year = (try? c.decode(FlexibleInt.self, forKey: .year))?.value
        artists = try c.decodeIfPresent([ArtistCredit].self, forKey: .artists) ?? []
        formats = try c.decodeIfPresent([ReleaseFormat].self, forKey: .formats) ?? []
        labels = try c.decodeIfPresent([ReleaseLabel].self, forKey: .labels) ?? []
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        thumbnailURL = try? c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
    }
}

public struct CollectionNote: Decodable, Sendable, Equatable {
    public let fieldID: CustomFieldID
    public let value: String
    enum CodingKeys: String, CodingKey { case value; case fieldID = "field_id" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fieldID = try CustomFieldID(c.decode(Int.self, forKey: .fieldID))
        value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
    }
}

public struct CollectionItem: Decodable, Sendable, Identifiable {
    public var id: CollectionInstanceID {
        instanceID
    }

    public let instanceID: CollectionInstanceID
    public let folderID: FolderID
    public let rating: Int
    public let basicInformation: BasicRelease
    public let notes: [CollectionNote]
    public let dateAdded: Date?

    enum CodingKeys: String, CodingKey {
        case rating, notes
        case instanceID = "instance_id"
        case folderID = "folder_id"
        case basicInformation = "basic_information"
        case dateAdded = "date_added"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        instanceID = try CollectionInstanceID(c.decode(Int.self, forKey: .instanceID))
        folderID = try FolderID(c.decode(Int.self, forKey: .folderID))
        rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        basicInformation = try c.decode(BasicRelease.self, forKey: .basicInformation)
        notes = try c.decodeIfPresent([CollectionNote].self, forKey: .notes) ?? []
        dateAdded = try c.decodeIfPresent(Date.self, forKey: .dateAdded)
    }
}

public struct CollectionAddition: Decodable, Sendable {
    public let instanceID: CollectionInstanceID
    public let resourceURL: URL?
    enum CodingKeys: String, CodingKey { case instanceID = "instance_id"; case resourceURL = "resource_url" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        instanceID = try CollectionInstanceID(c.decode(Int.self, forKey: .instanceID))
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
    }
}

public struct CollectionCustomField: Decodable, Sendable, Identifiable {
    public let id: CustomFieldID
    public let name: String
    public let type: String
    public let position: Int?
    public let publicField: Bool?
    public let options: [String]

    enum CodingKeys: String, CodingKey { case id, name, type, position, options; case publicField = "public" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try CustomFieldID(c.decode(Int.self, forKey: .id))
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(String.self, forKey: .type)
        position = try c.decodeIfPresent(Int.self, forKey: .position)
        publicField = try c.decodeIfPresent(Bool.self, forKey: .publicField)
        options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
    }
}

public struct CollectionValue: Decodable, Sendable, Equatable {
    /// Formatted currency text returned by Discogs, for example "$75.50".
    public let minimum: String
    public let median: String
    public let maximum: String
}

public struct WantlistItem: Decodable, Sendable, Identifiable {
    public var id: ReleaseID {
        basicInformation.id
    }

    public let rating: Int
    public let notes: String?
    public let resourceURL: URL?
    public let basicInformation: BasicRelease

    enum CodingKeys: String, CodingKey {
        case rating, notes
        case resourceURL = "resource_url"
        case basicInformation = "basic_information"
    }
}

public struct UserListSummary: Decodable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?
    public let publicList: Bool?
    public let numberOfItems: Int?
    public let resourceURL: URL?
    public let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case publicList = "public"
        case numberOfItems = "num_items"
        case resourceURL = "resource_url"
        case webURL = "uri"
    }
}

public struct UserList: Decodable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?
    public let publicList: Bool?
    public let items: [UserListItem]
    public let resourceURL: URL?
    public let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, listID = "list_id", name, description, items
        case publicList = "public"
        case resourceURL = "resource_url"
        case webURL = "uri", url
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? c.decode(Int.self, forKey: .listID)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        publicList = try c.decodeIfPresent(Bool.self, forKey: .publicList)
        items = try c.decodeIfPresent([UserListItem].self, forKey: .items) ?? []
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        webURL = (try? c.decodeIfPresent(URL.self, forKey: .webURL)) ?? (try? c.decodeIfPresent(
            URL.self,
            forKey: .url
        ))
    }
}

public struct UserListItem: Decodable, Sendable, Identifiable {
    public let id: Int
    public let type: String
    public let displayTitle: String?
    public let comment: String?
    public let resourceURL: URL?
    enum CodingKeys: String,
        CodingKey { case id, type, comment; case displayTitle = "display_title"; case resourceURL = "resource_url" }
}
