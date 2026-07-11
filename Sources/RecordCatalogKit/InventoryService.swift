import Foundation

public struct InventoryService: Sendable {
    let core: ClientCore

    public func listings(
        for username: String,
        filters: InventoryFilters = .init(),
        pageSize: Int = 50
    ) -> Paginator<MarketplaceListing> {
        Paginator(pageSize: pageSize) { [core] page in
            let response: InventoryResponse = try await core.send(.get(
                "/users/\(escapedPath(username))/inventory",
                query: page.validated().queryItems + filters.queryItems
            ))
            return Page(items: response.listings, metadata: response.pagination)
        }
    }

    public func startExport() async throws -> ExportID {
        let response = try await core.sendRaw(
            RawEndpoint(method: .post, path: "/inventory/export", authentication: .user)
        )
        return try Self.locationID(response.response, as: ExportID.self)
    }

    public func exports(pageSize: Int = 50) -> Paginator<InventoryExport> {
        Paginator(pageSize: pageSize) { [core] page in
            let response: ExportsResponse = try await core.send(.get(
                "/inventory/export",
                query: page.validated().queryItems,
                authentication: .user
            ))
            return Page(items: response.items, metadata: response.pagination)
        }
    }

    public func export(id: ExportID) async throws -> InventoryExport {
        try await core.send(.get("/inventory/export/\(id.rawValue)", authentication: .user))
    }

    public func downloadExport(id: ExportID) async throws -> Data {
        try await core.sendData(RawEndpoint(path: "/inventory/export/\(id.rawValue)/download", authentication: .user))
    }

    @discardableResult
    public func downloadExport(id: ExportID, to destination: URL) async throws -> URL {
        let data = try await downloadExport(id: id)
        do {
            try data.write(to: destination, options: .atomic)
            return destination
        } catch {
            throw RecordCatalogError.file("Could not write inventory export: \(error.localizedDescription)")
        }
    }

    public func uploadAdd(_ rows: [InventoryAddRow]) async throws -> UploadID {
        try await upload(CSVEncoder.add(rows), path: "/inventory/upload/add")
    }

    public func uploadChanges(_ rows: [InventoryChangeRow]) async throws -> UploadID {
        try await upload(CSVEncoder.change(rows), path: "/inventory/upload/change")
    }

    public func uploadDeletes(_ rows: [InventoryDeleteRow]) async throws -> UploadID {
        try await upload(CSVEncoder.delete(rows), path: "/inventory/upload/delete")
    }

    public func uploads(pageSize: Int = 50) -> Paginator<InventoryUpload> {
        Paginator(pageSize: pageSize) { [core] page in
            let response: UploadsResponse = try await core.send(.get(
                "/inventory/upload",
                query: page.validated().queryItems,
                authentication: .user
            ))
            return Page(items: response.items, metadata: response.pagination)
        }
    }

    public func upload(id: UploadID) async throws -> InventoryUpload {
        try await core.send(.get("/inventory/upload/\(id.rawValue)", authentication: .user))
    }

    private func upload(_ csv: String, path: String) async throws -> UploadID {
        let boundary = "RecordCatalogKit-\(UUID().uuidString)"
        var data = Data()
        data.append(Data("--\(boundary)\r\n".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"upload\"; filename=\"inventory.csv\"\r\n".utf8))
        data.append(Data("Content-Type: text/csv; charset=utf-8\r\n\r\n".utf8))
        data.append(Data(csv.utf8))
        data.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let response = try await core.sendRaw(RawEndpoint(
            method: .post,
            path: path,
            body: .raw(data, contentType: "multipart/form-data; boundary=\(boundary)"),
            authentication: .user
        ))
        return try Self.locationID(response.response, as: UploadID.self)
    }

    private static func locationID<ID: IntegerDiscogsID>(
        _ response: HTTPURLResponse,
        as type: ID.Type
    ) throws -> ID {
        guard let location = response.value(forHTTPHeaderField: "Location"),
              let rawID = Int(URL(string: location)?.lastPathComponent ?? "")
        else {
            throw RecordCatalogError.invalidResponse
        }
        return ID(rawValue: rawID)
    }
}

public struct InventoryExport: Decodable, Sendable, Identifiable {
    public let id: ExportID
    public let status: String
    public let created: Date?
    public let finished: Date?
    public let downloadURL: URL?
    public let filename: String?

    enum CodingKeys: String, CodingKey {
        case id, status, filename
        case created = "created_ts"
        case finished = "finished_ts"
        case downloadURL = "download_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try ExportID(c.decode(Int.self, forKey: .id))
        status = try c.decode(String.self, forKey: .status)
        created = try c.decodeIfPresent(Date.self, forKey: .created)
        finished = try c.decodeIfPresent(Date.self, forKey: .finished)
        downloadURL = try? c.decodeIfPresent(URL.self, forKey: .downloadURL)
        filename = try c.decodeIfPresent(String.self, forKey: .filename)
    }
}

public struct InventoryUpload: Decodable, Sendable, Identifiable {
    public let id: UploadID
    public let status: String
    public let created: Date?
    public let finished: Date?
    public let filename: String?
    public let results: String?
    public let type: String?

    enum CodingKeys: String, CodingKey {
        case id, status, filename, results, type
        case created = "created_ts"
        case finished = "finished_ts"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try UploadID(c.decode(Int.self, forKey: .id))
        status = try c.decode(String.self, forKey: .status)
        created = try c.decodeIfPresent(Date.self, forKey: .created)
        finished = try c.decodeIfPresent(Date.self, forKey: .finished)
        filename = try c.decodeIfPresent(String.self, forKey: .filename)
        results = try c.decodeIfPresent(String.self, forKey: .results)
        type = try c.decodeIfPresent(String.self, forKey: .type)
    }
}

public struct InventoryAddRow: Sendable {
    public let releaseID: ReleaseID
    public let mediaCondition: MediaCondition
    public let price: Decimal
    public var sleeveCondition: SleeveCondition?
    public var comments: String?
    public var acceptOffer: Bool?
    public var externalID: String?
    public var location: String?
    public var weight: Int?
    public var formatQuantity: Int?

    public init(
        releaseID: ReleaseID,
        mediaCondition: MediaCondition,
        price: Decimal,
        sleeveCondition: SleeveCondition? = nil,
        comments: String? = nil,
        acceptOffer: Bool? = nil,
        externalID: String? = nil,
        location: String? = nil,
        weight: Int? = nil,
        formatQuantity: Int? = nil
    ) {
        self.releaseID = releaseID; self.mediaCondition = mediaCondition; self.price = price
        self.sleeveCondition = sleeveCondition; self.comments = comments; self.acceptOffer = acceptOffer
        self.externalID = externalID; self.location = location
        self.weight = weight; self.formatQuantity = formatQuantity
    }
}

public struct InventoryChangeRow: Sendable {
    public let releaseID: ReleaseID
    public var mediaCondition: MediaCondition?
    public var sleeveCondition: SleeveCondition?
    public var price: Decimal?
    public var comments: String?
    public var acceptOffer: Bool?
    public var location: String?
    public var externalID: String?
    public var weight: Int?
    public var formatQuantity: Int?
    public init(
        releaseID: ReleaseID,
        mediaCondition: MediaCondition? = nil,
        sleeveCondition: SleeveCondition? = nil,
        price: Decimal? = nil,
        comments: String? = nil,
        acceptOffer: Bool? = nil,
        location: String? = nil,
        externalID: String? = nil,
        weight: Int? = nil,
        formatQuantity: Int? = nil
    ) {
        self.releaseID = releaseID; self.mediaCondition = mediaCondition; self.sleeveCondition = sleeveCondition
        self.price = price; self.comments = comments; self.acceptOffer = acceptOffer; self.location = location
        self.externalID = externalID; self.weight = weight; self.formatQuantity = formatQuantity
    }
}

public struct InventoryDeleteRow: Sendable {
    public let listingID: ListingID
    public init(listingID: ListingID) {
        self.listingID = listingID
    }
}

enum CSVEncoder {
    static func add(_ rows: [InventoryAddRow]) -> String {
        table(
            header: [
                "release_id",
                "price",
                "media_condition",
                "sleeve_condition",
                "comments",
                "accept_offer",
                "location",
                "external_id",
                "weight",
                "format_quantity",
            ],
            rows: rows.map { [
                String($0.releaseID.rawValue),
                String(describing: $0.price),
                $0.mediaCondition.rawValue,
                $0.sleeveCondition?.rawValue ?? "",
                $0.comments ?? "",
                bool($0.acceptOffer),
                $0.location ?? "",
                $0.externalID ?? "",
                $0.weight.map(String.init) ?? "",
                $0.formatQuantity.map(String.init) ?? "",
            ] }
        )
    }

    static func change(_ rows: [InventoryChangeRow]) -> String {
        table(
            header: [
                "release_id",
                "price",
                "media_condition",
                "sleeve_condition",
                "comments",
                "accept_offer",
                "external_id",
                "location",
                "weight",
                "format_quantity",
            ],
            rows: rows.map { [
                String($0.releaseID.rawValue),
                $0.price.map(String.init(describing:)) ?? "",
                $0.mediaCondition?.rawValue ?? "",
                $0.sleeveCondition?.rawValue ?? "",
                $0.comments ?? "",
                bool($0.acceptOffer),
                $0.externalID ?? "",
                $0.location ?? "",
                $0.weight.map(String.init) ?? "",
                $0.formatQuantity.map(String.init) ?? "",
            ] }
        )
    }

    static func delete(_ rows: [InventoryDeleteRow]) -> String {
        table(header: ["listing_id"], rows: rows.map { [String($0.listingID.rawValue)] })
    }

    private static func bool(_ value: Bool?) -> String {
        value.map { $0 ? "Y" : "N" } ?? ""
    }

    private static func table(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private struct InventoryResponse: Decodable,
    Sendable { let pagination: PageMetadata; let listings: [MarketplaceListing] }
private struct ExportsResponse: Decodable, Sendable {
    let pagination: PageMetadata
    let items: [InventoryExport]
    enum CodingKeys: String, CodingKey { case pagination; case items }
}

private struct UploadsResponse: Decodable, Sendable {
    let pagination: PageMetadata
    let items: [InventoryUpload]
    enum CodingKeys: String, CodingKey { case pagination; case items }
}
