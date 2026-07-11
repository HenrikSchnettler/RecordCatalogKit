import Foundation

public struct DatabaseService: Sendable {
    let core: ClientCore

    public func release(id: ReleaseID, currency: Currency? = nil) async throws -> Release {
        try await core.send(.get(
            "/releases/\(id.rawValue)",
            query: [query("curr_abbr", currency?.rawValue)].compactMap(\.self)
        ))
    }

    public func master(id: MasterID) async throws -> MasterRelease {
        try await core.send(.get("/masters/\(id.rawValue)"))
    }

    public func artist(id: ArtistID) async throws -> Artist {
        try await core.send(.get("/artists/\(id.rawValue)"))
    }

    public func label(id: LabelID) async throws -> Label {
        try await core.send(.get("/labels/\(id.rawValue)"))
    }

    public func rating(for releaseID: ReleaseID, username: String) async throws -> UserReleaseRating {
        let username = try escapedPath(username)
        return try await core.send(.get(
            "/releases/\(releaseID.rawValue)/rating/\(username)",
            authentication: .user
        ))
    }

    @discardableResult
    public func setRating(_ rating: Int, for releaseID: ReleaseID, username: String) async throws -> UserReleaseRating {
        guard (1 ... 5).contains(rating) else {
            throw RecordCatalogError.invalidRequest("A release rating must be between 1 and 5.")
        }
        struct Body: Encodable { let rating: Int }
        return try await core.send(.request(
            .put,
            "/releases/\(releaseID.rawValue)/rating/\(escapedPath(username))",
            body: jsonBody(Body(rating: rating))
        ))
    }

    public func deleteRating(for releaseID: ReleaseID, username: String) async throws {
        try await core.sendVoid(.request(
            .delete,
            "/releases/\(releaseID.rawValue)/rating/\(escapedPath(username))"
        ))
    }

    public func communityRating(for releaseID: ReleaseID) async throws -> CommunityReleaseRating {
        try await core.send(.get("/releases/\(releaseID.rawValue)/rating"))
    }

    public func statistics(for releaseID: ReleaseID) async throws -> ReleaseStatistics {
        try await core.send(.get("/releases/\(releaseID.rawValue)/stats"))
    }

    public func masterVersions(
        for masterID: MasterID,
        filters: MasterVersionFilters = .init(),
        pageSize: Int = 50
    ) -> Paginator<MasterVersion> {
        Paginator(pageSize: pageSize) { [core] page in
            let response: MasterVersionsResponse = try await core.send(.get(
                "/masters/\(masterID.rawValue)/versions",
                query: page.validated().queryItems + filters.queryItems
            ))
            return Page(items: response.versions, metadata: response.pagination)
        }
    }

    public func artistReleases(
        for artistID: ArtistID,
        sort: ArtistReleaseSort? = nil,
        order: SortOrder? = nil,
        pageSize: Int = 50
    ) -> Paginator<ArtistRelease> {
        Paginator(pageSize: pageSize) { [core] page in
            let extra = [query("sort", sort?.rawValue), query("sort_order", order?.rawValue)].compactMap(\.self)
            let response: ArtistReleasesResponse = try await core.send(.get(
                "/artists/\(artistID.rawValue)/releases",
                query: page.validated().queryItems + extra
            ))
            return Page(items: response.releases, metadata: response.pagination)
        }
    }

    public func labelReleases(for labelID: LabelID, pageSize: Int = 50) -> Paginator<LabelRelease> {
        Paginator(pageSize: pageSize) { [core] page in
            let response: LabelReleasesResponse = try await core.send(.get(
                "/labels/\(labelID.rawValue)/releases",
                query: page.validated().queryItems
            ))
            return Page(items: response.releases, metadata: response.pagination)
        }
    }

    public func search(_ search: DatabaseSearchQuery, pageSize: Int = 50) -> Paginator<SearchResult> {
        Paginator(pageSize: pageSize) { [core] page in
            let response: SearchResponse = try await core.send(.get(
                "/database/search",
                query: page.validated().queryItems + search.queryItems,
                authentication: .authenticated
            ))
            return Page(items: response.results, metadata: response.pagination)
        }
    }
}

public struct DatabaseSearchQuery: Sendable {
    public var query: String?
    public var type: SearchType?
    public var title: String?
    public var releaseTitle: String?
    public var credit: String?
    public var artist: String?
    public var artistNameVariation: String?
    public var label: String?
    public var genre: String?
    public var style: String?
    public var country: String?
    public var year: String?
    public var format: String?
    public var catalogNumber: String?
    public var barcode: String?
    public var track: String?
    public var submitter: String?
    public var contributor: String?

    public init(
        query: String? = nil,
        type: SearchType? = nil,
        title: String? = nil,
        releaseTitle: String? = nil,
        credit: String? = nil,
        artist: String? = nil,
        artistNameVariation: String? = nil,
        label: String? = nil,
        genre: String? = nil,
        style: String? = nil,
        country: String? = nil,
        year: String? = nil,
        format: String? = nil,
        catalogNumber: String? = nil,
        barcode: String? = nil,
        track: String? = nil,
        submitter: String? = nil,
        contributor: String? = nil
    ) {
        self.query = query; self.type = type; self.title = title; self.releaseTitle = releaseTitle
        self.credit = credit; self.artist = artist; self.artistNameVariation = artistNameVariation
        self.label = label; self.genre = genre; self.style = style; self.country = country
        self.year = year; self.format = format; self.catalogNumber = catalogNumber
        self.barcode = barcode; self.track = track; self.submitter = submitter; self.contributor = contributor
    }

    var queryItems: [URLQueryItem] {
        [
            query.map { URLQueryItem(name: "q", value: $0) },
            type.map { URLQueryItem(name: "type", value: $0.rawValue) },
            title.map { URLQueryItem(name: "title", value: $0) },
            releaseTitle.map { URLQueryItem(name: "release_title", value: $0) },
            credit.map { URLQueryItem(name: "credit", value: $0) },
            artist.map { URLQueryItem(name: "artist", value: $0) },
            artistNameVariation.map { URLQueryItem(name: "anv", value: $0) },
            label.map { URLQueryItem(name: "label", value: $0) },
            genre.map { URLQueryItem(name: "genre", value: $0) },
            style.map { URLQueryItem(name: "style", value: $0) },
            country.map { URLQueryItem(name: "country", value: $0) },
            year.map { URLQueryItem(name: "year", value: $0) },
            format.map { URLQueryItem(name: "format", value: $0) },
            catalogNumber.map { URLQueryItem(name: "catno", value: $0) },
            barcode.map { URLQueryItem(name: "barcode", value: $0) },
            track.map { URLQueryItem(name: "track", value: $0) },
            submitter.map { URLQueryItem(name: "submitter", value: $0) },
            contributor.map { URLQueryItem(name: "contributor", value: $0) },
        ].compactMap(\.self)
    }
}

public struct SearchType: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let release = Self("release"), master = Self("master"), artist = Self("artist"), label = Self("label")
}

public struct SortOrder: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let ascending = Self("asc"), descending = Self("desc")
}

public struct ArtistReleaseSort: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let year = Self("year"), title = Self("title"), format = Self("format")
}

public struct MasterVersionFilters: Sendable {
    public var format: String?
    public var label: String?
    public var released: String?
    public var country: String?
    public var sort: String?
    public var order: SortOrder?

    public init(
        format: String? = nil,
        label: String? = nil,
        released: String? = nil,
        country: String? = nil,
        sort: String? = nil,
        order: SortOrder? = nil
    ) {
        self.format = format; self.label = label; self.released = released; self.country = country; self
            .sort = sort; self.order = order
    }

    var queryItems: [URLQueryItem] {
        [
            query("format", format),
            query("label", label),
            query("released", released),
            query("country", country),
            query("sort", sort),
            query("sort_order", order?.rawValue),
        ].compactMap(\.self)
    }
}

private struct MasterVersionsResponse: Decodable,
    Sendable { let pagination: PageMetadata; let versions: [MasterVersion] }
private struct ArtistReleasesResponse: Decodable,
    Sendable { let pagination: PageMetadata; let releases: [ArtistRelease] }
private struct LabelReleasesResponse: Decodable, Sendable { let pagination: PageMetadata; let releases: [LabelRelease] }
private struct SearchResponse: Decodable, Sendable { let pagination: PageMetadata; let results: [SearchResult] }
