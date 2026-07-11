import Foundation

public struct ArtistCredit: Decodable, Sendable, Equatable, Identifiable {
    public let id: ArtistID
    public let name: String
    public let anv: String?
    public let join: String?
    public let role: String?
    public let tracks: String?
    public let resourceURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, anv, join, role, tracks
        case resourceURL = "resource_url"
    }
}

public struct Track: Decodable, Sendable, Equatable {
    public let position: String?
    public let type: String?
    public let title: String
    public let duration: String?
    public let artists: [ArtistCredit]?
    public let extraArtists: [ArtistCredit]?

    enum CodingKeys: String, CodingKey {
        case position, type, title, duration, artists
        case extraArtists = "extraartists"
    }
}

public struct ReleaseFormat: Decodable, Sendable, Equatable {
    public let name: String
    public let quantity: String?
    public let descriptions: [String]?
    public let text: String?
}

public struct ReleaseLabel: Decodable, Sendable, Equatable, Identifiable {
    public let id: LabelID
    public let name: String
    public let catalogNumber: String?
    public let entityType: String?
    public let resourceURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name
        case catalogNumber = "catno"
        case entityType = "entity_type_name"
        case resourceURL = "resource_url"
    }
}

public struct ReleaseIdentifier: Decodable, Sendable, Equatable {
    public let type: String
    public let value: String
    public let description: String?
}

public struct Video: Decodable, Sendable, Equatable {
    public let uri: URL?
    public let title: String
    public let description: String?
    public let duration: Int?
    public let embed: Bool?
}

public struct CommunityRating: Decodable, Sendable, Equatable {
    public let average: Double
    public let count: Int
}

public struct ReleaseCommunity: Decodable, Sendable, Equatable {
    public let have: Int
    public let want: Int
    public let rating: CommunityRating?
    public let status: String?
    public let dataQuality: String?

    enum CodingKeys: String, CodingKey {
        case have, want, rating, status
        case dataQuality = "data_quality"
    }
}

public struct Release: Decodable, Sendable, Identifiable {
    public let id: ReleaseID
    public let title: String
    public let artists: [ArtistCredit]
    public let extraArtists: [ArtistCredit]?
    public let labels: [ReleaseLabel]
    public let formats: [ReleaseFormat]
    public let identifiers: [ReleaseIdentifier]
    public let tracklist: [Track]
    public let genres: [String]
    public let styles: [String]
    public let country: String?
    public let year: Int?
    public let released: ReleaseDate?
    public let notes: String?
    public let dataQuality: String?
    public let masterID: MasterID?
    public let masterURL: URL?
    public let resourceURL: URL?
    public let webURL: URL?
    public let thumbnailURL: URL?
    public let images: [ImageResource]
    public let videos: [Video]
    public let community: ReleaseCommunity?
    public let lowestPrice: Decimal?
    public let numberForSale: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, artists, labels, formats, identifiers, tracklist, genres, styles
        case country, year, released, notes, images, videos, community
        case extraArtists = "extraartists"
        case dataQuality = "data_quality"
        case masterID = "master_id"
        case masterURL = "master_url"
        case resourceURL = "resource_url"
        case webURL = "uri"
        case thumbnailURL = "thumb"
        case lowestPrice = "lowest_price"
        case numberForSale = "num_for_sale"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ReleaseID(c.decode(Int.self, forKey: .id))
        title = try c.decode(String.self, forKey: .title)
        artists = try c.decodeIfPresent([ArtistCredit].self, forKey: .artists) ?? []
        extraArtists = try c.decodeIfPresent([ArtistCredit].self, forKey: .extraArtists)
        labels = try c.decodeIfPresent([ReleaseLabel].self, forKey: .labels) ?? []
        formats = try c.decodeIfPresent([ReleaseFormat].self, forKey: .formats) ?? []
        identifiers = try c.decodeIfPresent([ReleaseIdentifier].self, forKey: .identifiers) ?? []
        tracklist = try c.decodeIfPresent([Track].self, forKey: .tracklist) ?? []
        genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        styles = try c.decodeIfPresent([String].self, forKey: .styles) ?? []
        country = try c.decodeIfPresent(String.self, forKey: .country)
        year = (try? c.decode(FlexibleInt.self, forKey: .year))?.value
        released = try c.decodeIfPresent(String.self, forKey: .released).map(ReleaseDate.init)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        dataQuality = try c.decodeIfPresent(String.self, forKey: .dataQuality)
        masterID = try c.decodeIfPresent(Int.self, forKey: .masterID).map(MasterID.init)
        masterURL = try? c.decodeIfPresent(URL.self, forKey: .masterURL)
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        webURL = try? c.decodeIfPresent(URL.self, forKey: .webURL)
        thumbnailURL = try? c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        images = try c.decodeIfPresent([ImageResource].self, forKey: .images) ?? []
        videos = try c.decodeIfPresent([Video].self, forKey: .videos) ?? []
        community = try c.decodeIfPresent(ReleaseCommunity.self, forKey: .community)
        lowestPrice = try c.decodeIfPresent(Decimal.self, forKey: .lowestPrice)
        numberForSale = try c.decodeIfPresent(Int.self, forKey: .numberForSale)
    }
}

public struct MasterRelease: Decodable, Sendable, Identifiable {
    public let id: MasterID
    public let title: String
    public let year: Int?
    public let mainReleaseID: ReleaseID?
    public let artists: [ArtistCredit]
    public let tracklist: [Track]
    public let genres: [String]
    public let styles: [String]
    public let images: [ImageResource]
    public let videos: [Video]
    public let resourceURL: URL?
    public let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, year, artists, tracklist, genres, styles, images, videos
        case mainReleaseID = "main_release"
        case resourceURL = "resource_url"
        case webURL = "uri"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try MasterID(c.decode(Int.self, forKey: .id))
        title = try c.decode(String.self, forKey: .title)
        year = (try? c.decode(FlexibleInt.self, forKey: .year))?.value
        mainReleaseID = try c.decodeIfPresent(Int.self, forKey: .mainReleaseID).map(ReleaseID.init)
        artists = try c.decodeIfPresent([ArtistCredit].self, forKey: .artists) ?? []
        tracklist = try c.decodeIfPresent([Track].self, forKey: .tracklist) ?? []
        genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        styles = try c.decodeIfPresent([String].self, forKey: .styles) ?? []
        images = try c.decodeIfPresent([ImageResource].self, forKey: .images) ?? []
        videos = try c.decodeIfPresent([Video].self, forKey: .videos) ?? []
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        webURL = try? c.decodeIfPresent(URL.self, forKey: .webURL)
    }
}

public struct MasterVersion: Decodable, Sendable, Identifiable {
    public let id: ReleaseID
    public let title: String
    public let label: String?
    public let catalogNumber: String?
    public let country: String?
    public let released: ReleaseDate?
    public let format: String?
    public let majorFormats: [String]
    public let status: String?
    public let resourceURL: URL?
    public let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, label, country, released, format, status
        case catalogNumber = "catno"
        case majorFormats = "major_formats"
        case resourceURL = "resource_url"
        case thumbnailURL = "thumb"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ReleaseID(c.decode(Int.self, forKey: .id))
        title = try c.decode(String.self, forKey: .title)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        catalogNumber = try c.decodeIfPresent(String.self, forKey: .catalogNumber)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        released = try c.decodeIfPresent(String.self, forKey: .released).map(ReleaseDate.init)
        format = try c.decodeIfPresent(String.self, forKey: .format)
        majorFormats = try c.decodeIfPresent([String].self, forKey: .majorFormats) ?? []
        status = try c.decodeIfPresent(String.self, forKey: .status)
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        thumbnailURL = try? c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
    }
}

public struct Artist: Decodable, Sendable, Identifiable {
    public let id: ArtistID
    public let name: String
    public let realName: String?
    public let profile: String?
    public let nameVariations: [String]
    public let aliases: [NamedResource]
    public let members: [NamedResource]
    public let groups: [NamedResource]
    public let urls: [URL]
    public let images: [ImageResource]
    public let resourceURL: URL?
    public let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, profile, aliases, members, groups, urls, images
        case realName = "realname"
        case nameVariations = "namevariations"
        case resourceURL = "resource_url"
        case webURL = "uri"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ArtistID(c.decode(Int.self, forKey: .id))
        name = try c.decode(String.self, forKey: .name)
        realName = try c.decodeIfPresent(String.self, forKey: .realName)
        profile = try c.decodeIfPresent(String.self, forKey: .profile)
        nameVariations = try c.decodeIfPresent([String].self, forKey: .nameVariations) ?? []
        aliases = try c.decodeIfPresent([NamedResource].self, forKey: .aliases) ?? []
        members = try c.decodeIfPresent([NamedResource].self, forKey: .members) ?? []
        groups = try c.decodeIfPresent([NamedResource].self, forKey: .groups) ?? []
        urls = (try? c.decodeIfPresent([URL].self, forKey: .urls)) ?? []
        images = try c.decodeIfPresent([ImageResource].self, forKey: .images) ?? []
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        webURL = try? c.decodeIfPresent(URL.self, forKey: .webURL)
    }
}

public struct NamedResource: Decodable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let resourceURL: URL?
    public let active: Bool?
    enum CodingKeys: String, CodingKey { case id, name, active; case resourceURL = "resource_url" }
}

public struct ArtistRelease: Decodable, Sendable, Identifiable {
    public let id: Int
    public let title: String
    public let artist: String?
    public let type: String
    public let role: String?
    public let year: Int?
    public let format: String?
    public let label: String?
    public let resourceURL: URL?
    public let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, type, role, year, format, label
        case resourceURL = "resource_url"
        case thumbnailURL = "thumb"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist)
        type = try c.decode(String.self, forKey: .type)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        year = (try? c.decode(FlexibleInt.self, forKey: .year))?.value
        format = try c.decodeIfPresent(String.self, forKey: .format)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        thumbnailURL = try? c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
    }
}

public struct Label: Decodable, Sendable, Identifiable {
    public let id: LabelID
    public let name: String
    public let profile: String?
    public let contactInformation: String?
    public let parentLabel: NamedResource?
    public let sublabels: [NamedResource]
    public let urls: [URL]
    public let images: [ImageResource]
    public let resourceURL: URL?
    public let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, profile, sublabels, urls, images
        case contactInformation = "contact_info"
        case parentLabel = "parent_label"
        case resourceURL = "resource_url"
        case webURL = "uri"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try LabelID(c.decode(Int.self, forKey: .id))
        name = try c.decode(String.self, forKey: .name)
        profile = try c.decodeIfPresent(String.self, forKey: .profile)
        contactInformation = try c.decodeIfPresent(String.self, forKey: .contactInformation)
        parentLabel = try c.decodeIfPresent(NamedResource.self, forKey: .parentLabel)
        sublabels = try c.decodeIfPresent([NamedResource].self, forKey: .sublabels) ?? []
        urls = (try? c.decodeIfPresent([URL].self, forKey: .urls)) ?? []
        images = try c.decodeIfPresent([ImageResource].self, forKey: .images) ?? []
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        webURL = try? c.decodeIfPresent(URL.self, forKey: .webURL)
    }
}

public struct LabelRelease: Decodable, Sendable, Identifiable {
    public let id: ReleaseID
    public let title: String
    public let artist: String?
    public let catalogNumber: String?
    public let year: Int?
    public let format: String?
    public let status: String?
    public let resourceURL: URL?
    public let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, year, format, status
        case catalogNumber = "catno"
        case resourceURL = "resource_url"
        case thumbnailURL = "thumb"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ReleaseID(c.decode(Int.self, forKey: .id))
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist)
        catalogNumber = try c.decodeIfPresent(String.self, forKey: .catalogNumber)
        year = (try? c.decode(FlexibleInt.self, forKey: .year))?.value
        format = try c.decodeIfPresent(String.self, forKey: .format)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        thumbnailURL = try? c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
    }
}

public struct SearchResult: Decodable, Sendable, Identifiable {
    public let id: Int
    public let type: String
    public let title: String
    public let country: String?
    public let year: Int?
    public let formats: [String]
    public let labels: [String]
    public let genres: [String]
    public let styles: [String]
    public let catalogNumber: String?
    public let barcode: [String]
    public let resourceURL: URL?
    public let webPath: String?
    public let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, type, title, country, year, genres, styles, barcode
        case formats = "format"
        case labels = "label"
        case catalogNumber = "catno"
        case resourceURL = "resource_url"
        case webPath = "uri"
        case thumbnailURL = "thumb"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        title = try c.decode(String.self, forKey: .title)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        year = (try? c.decode(FlexibleInt.self, forKey: .year))?.value
        formats = try c.decodeIfPresent([String].self, forKey: .formats) ?? []
        labels = try c.decodeIfPresent([String].self, forKey: .labels) ?? []
        genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        styles = try c.decodeIfPresent([String].self, forKey: .styles) ?? []
        catalogNumber = try c.decodeIfPresent(String.self, forKey: .catalogNumber)
        barcode = try c.decodeIfPresent([String].self, forKey: .barcode) ?? []
        resourceURL = try? c.decodeIfPresent(URL.self, forKey: .resourceURL)
        webPath = try c.decodeIfPresent(String.self, forKey: .webPath)
        thumbnailURL = try? c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
    }
}

public struct UserReleaseRating: Decodable, Sendable, Equatable {
    public let username: String
    public let releaseID: ReleaseID
    public let rating: Int
    enum CodingKeys: String, CodingKey { case username, rating; case releaseID = "release_id" }
}

public struct CommunityReleaseRating: Decodable, Sendable, Equatable {
    public let releaseID: ReleaseID
    public let rating: CommunityRating
    enum CodingKeys: String, CodingKey { case rating; case releaseID = "release_id" }
}

public struct ReleaseStatistics: Decodable, Sendable, Equatable {
    public let have: Int
    public let want: Int
    enum CodingKeys: String, CodingKey { case have = "num_have", want = "num_want" }
}
