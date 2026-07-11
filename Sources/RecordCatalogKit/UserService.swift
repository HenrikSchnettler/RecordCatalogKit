import Foundation

public struct UserResource: Sendable {
    let core: ClientCore
    public let username: String

    public var collection: CollectionService {
        CollectionService(core: core, username: username)
    }

    public var wantlist: WantlistService {
        WantlistService(core: core, username: username)
    }

    public func profile() async throws -> UserProfile {
        try await core.send(.get("/users/\(escapedPath(username))"))
    }

    @discardableResult
    public func updateProfile(_ changes: ProfileChanges) async throws -> UserProfile {
        try await core.send(.request(
            .post,
            "/users/\(escapedPath(username))",
            body: jsonBody(changes)
        ))
    }

    public func submissions(pageSize: Int = 50) -> Paginator<Submission> {
        Paginator(pageSize: pageSize) { [core, username] page in
            let response: SubmissionsResponse = try await core.send(.get(
                "/users/\(escapedPath(username))/submissions",
                query: page.validated().queryItems
            ))
            return Page(items: response.submissions, metadata: response.pagination)
        }
    }

    public func contributions(
        sort: ContributionSort? = nil,
        order: SortOrder? = nil,
        pageSize: Int = 50
    ) -> Paginator<Contribution> {
        Paginator(pageSize: pageSize) { [core, username] page in
            let extra = [query("sort", sort?.rawValue), query("sort_order", order?.rawValue)].compactMap(\.self)
            let response: ContributionsResponse = try await core.send(.get(
                "/users/\(escapedPath(username))/contributions",
                query: page.validated().queryItems + extra
            ))
            return Page(items: response.contributions, metadata: response.pagination)
        }
    }

    public func lists(pageSize: Int = 50) -> Paginator<UserListSummary> {
        Paginator(pageSize: pageSize) { [core, username] page in
            let response: ListsResponse = try await core.send(.get(
                "/users/\(escapedPath(username))/lists",
                query: page.validated().queryItems
            ))
            return Page(items: response.lists, metadata: response.pagination)
        }
    }

    public func list(id: Int) async throws -> UserList {
        try await core.send(.get("/lists/\(id)"))
    }
}

public struct ContributionSort: ExtensibleStringValue {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let label = Self("label"), artist = Self("artist"), title = Self("title"),
                      catalogNumber = Self("catno"), format = Self("format"), rating = Self("rating"),
                      year = Self("year"), added = Self("added")
}

public struct CollectionService: Sendable {
    let core: ClientCore
    let username: String

    private func root() throws -> String {
        try "/users/\(escapedPath(username))/collection"
    }

    public func folders() async throws -> [CollectionFolder] {
        struct Response: Decodable, Sendable { let folders: [CollectionFolder] }
        let response: Response = try await core.send(.get("\(root())/folders"))
        return response.folders
    }

    @discardableResult
    public func createFolder(named name: String) async throws -> CollectionFolder {
        struct Body: Encodable { let name: String }
        return try await core.send(.request(.post, "\(root())/folders", body: jsonBody(Body(name: name))))
    }

    @discardableResult
    public func renameFolder(_ folderID: FolderID, to name: String) async throws -> CollectionFolder {
        struct Body: Encodable { let name: String }
        return try await core.send(.request(
            .post,
            "\(root())/folders/\(folderID.rawValue)",
            body: jsonBody(Body(name: name))
        ))
    }

    public func deleteFolder(_ folderID: FolderID) async throws {
        try await core.sendVoid(.request(.delete, "\(root())/folders/\(folderID.rawValue)"))
    }

    public func items(for releaseID: ReleaseID) async throws -> [CollectionItem] {
        struct Response: Decodable, Sendable { let releases: [CollectionItem] }
        let response: Response = try await core.send(.get("\(root())/releases/\(releaseID.rawValue)"))
        return response.releases
    }

    public func items(in folderID: FolderID, pageSize: Int = 50) -> Paginator<CollectionItem> {
        Paginator(pageSize: pageSize) { [core, username] page in
            let response: CollectionItemsResponse = try await core.send(.get(
                "/users/\(escapedPath(username))/collection/folders/\(folderID.rawValue)/releases",
                query: page.validated().queryItems
            ))
            return Page(items: response.releases, metadata: response.pagination)
        }
    }

    @discardableResult
    public func add(_ releaseID: ReleaseID, to folderID: FolderID) async throws -> CollectionAddition {
        try await core.send(.request(
            .post,
            "\(root())/folders/\(folderID.rawValue)/releases/\(releaseID.rawValue)"
        ))
    }

    @discardableResult
    public func setRating(
        _ rating: Int,
        releaseID: ReleaseID,
        instanceID: CollectionInstanceID,
        folderID: FolderID
    ) async throws -> CollectionItem {
        guard (0 ... 5).contains(rating)
        else { throw RecordCatalogError.invalidRequest("A rating must be between 0 and 5.") }
        struct Body: Encodable { let rating: Int }
        return try await core.send(.request(
            .post,
            "\(root())/folders/\(folderID.rawValue)/releases/\(releaseID.rawValue)/instances/\(instanceID.rawValue)",
            body: jsonBody(Body(rating: rating))
        ))
    }

    public func remove(
        releaseID: ReleaseID,
        instanceID: CollectionInstanceID,
        from folderID: FolderID
    ) async throws {
        try await core.sendVoid(.request(
            .delete,
            "\(root())/folders/\(folderID.rawValue)/releases/\(releaseID.rawValue)/instances/\(instanceID.rawValue)"
        ))
    }

    public func customFields() async throws -> [CollectionCustomField] {
        struct Response: Decodable, Sendable { let fields: [CollectionCustomField] }
        let response: Response = try await core.send(.get("\(root())/fields", authentication: .user))
        return response.fields
    }

    public func setCustomField(
        _ value: String,
        fieldID: CustomFieldID,
        releaseID: ReleaseID,
        instanceID: CollectionInstanceID,
        folderID: FolderID
    ) async throws {
        let endpoint: Endpoint<EmptyResponse> = try .request(
            .post,
            "\(root())/folders/\(folderID.rawValue)/releases/\(releaseID.rawValue)/instances/\(instanceID.rawValue)/fields/\(fieldID.rawValue)",
            query: [URLQueryItem(name: "value", value: value)]
        )
        try await core.sendVoid(endpoint)
    }

    public func value() async throws -> CollectionValue {
        try await core.send(.get("\(root())/value", authentication: .user))
    }
}

public struct WantlistService: Sendable {
    let core: ClientCore
    let username: String
    private func root() throws -> String {
        try "/users/\(escapedPath(username))/wants"
    }

    public func items(pageSize: Int = 50) -> Paginator<WantlistItem> {
        Paginator(pageSize: pageSize) { [core, username] page in
            let response: WantlistResponse = try await core.send(.get(
                "/users/\(escapedPath(username))/wants",
                query: page.validated().queryItems
            ))
            return Page(items: response.wants, metadata: response.pagination)
        }
    }

    @discardableResult
    public func add(_ releaseID: ReleaseID, notes: String? = nil, rating: Int? = nil) async throws -> WantlistItem {
        try validate(rating)
        return try await core.send(.request(
            .put,
            "\(root())/\(releaseID.rawValue)",
            query: [query("notes", notes), query("rating", rating)].compactMap(\.self)
        ))
    }

    @discardableResult
    public func update(_ releaseID: ReleaseID, notes: String? = nil, rating: Int? = nil) async throws -> WantlistItem {
        try validate(rating)
        return try await core.send(.request(
            .post,
            "\(root())/\(releaseID.rawValue)",
            query: [query("notes", notes), query("rating", rating)].compactMap(\.self)
        ))
    }

    public func remove(_ releaseID: ReleaseID) async throws {
        try await core.sendVoid(.request(.delete, "\(root())/\(releaseID.rawValue)"))
    }

    private func validate(_ rating: Int?) throws {
        if let rating,
           !(0 ... 5).contains(rating)
        {
            throw RecordCatalogError.invalidRequest("A rating must be between 0 and 5.")
        }
    }
}

private struct SubmissionsResponse: Decodable, Sendable {
    let pagination: PageMetadata
    let submissions: [Submission]

    private struct Groups: Decodable {
        let artists: [Artist]
        let labels: [Label]
        let releases: [Release]
    }

    private enum CodingKeys: String, CodingKey { case pagination, submissions }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pagination = try c.decode(PageMetadata.self, forKey: .pagination)
        let groups = try c.decode(Groups.self, forKey: .submissions)
        submissions = groups.artists.map(Submission.artist)
            + groups.labels.map(Submission.label)
            + groups.releases.map(Submission.release)
    }
}

private struct ContributionsResponse: Decodable,
    Sendable { let pagination: PageMetadata; let contributions: [Contribution] }
private struct ListsResponse: Decodable, Sendable { let pagination: PageMetadata; let lists: [UserListSummary] }
private struct CollectionItemsResponse: Decodable,
    Sendable { let pagination: PageMetadata; let releases: [CollectionItem] }
private struct WantlistResponse: Decodable, Sendable { let pagination: PageMetadata; let wants: [WantlistItem] }
