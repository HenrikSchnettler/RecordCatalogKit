import Foundation
@testable import RecordCatalogKit
import Testing

@Test func releaseDecodesSparseAndInconsistentJSON() throws {
    let json = #"{"id":9,"title":"Sparse","year":"1999","released":"1999-07","artists":[],"images":[],"unknown_future_field":true}"#
    let release = try JSONDecoder.recordCatalog.decode(Release.self, from: Data(json.utf8))
    #expect(release.year == 1999)
    #expect(release.released?.components?.year == 1999)
    #expect(release.released?.components?.month == 7)
    #expect(release.labels.isEmpty)
}

@Test func extensibleValuesPreserveUnknownServerValues() throws {
    let condition = try JSONDecoder().decode(MediaCondition.self, from: Data(#""Future Grade""#.utf8))
    #expect(condition.rawValue == "Future Grade")
}

@Test func listingCreationUsesTypedJSONAndCorrectEndpoint() async throws {
    let (client, transport) = try makeClient(
        authentication: .personalToken("private-token"),
        responses: [
            StubResponse(json: #"{"listing_id":42,"resource_url":"https://api.discogs.com/marketplace/listings/42"}"#),
        ]
    )
    let created = try await client.marketplace.createListing(
        ListingDraft(
            releaseID: ReleaseID(7),
            condition: .nearMint,
            price: #require(Decimal(string: "12.50")),
            comments: "Great copy",
            allowOffers: true
        )
    )
    #expect(created.listingID == ListingID(42))
    let request = try #require(await transport.capturedRequests().first)
    #expect(request.url?.path == "/marketplace/listings")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Discogs token=private-token")
    let body = try #require(request.httpBody)
    let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(object["release_id"] as? Int == 7)
    #expect(object["condition"] as? String == "Near Mint (NM or M-)")
    #expect(object["allow_offers"] as? Bool == true)
}

@Test func listingUpdateHandlesNoContentAndRefetchesListing() async throws {
    let (client, transport) = try makeClient(
        authentication: .personalToken("private-token"),
        responses: [
            StubResponse(statusCode: 204, data: Data()),
            StubResponse(
                json: #"{"id":42,"status":"Draft","condition":"Mint (M)","price":{"currency":"USD","value":12.5},"release":{"id":7,"title":"Release"}}"#
            ),
        ]
    )

    let listing = try await client.marketplace.updateListing(
        ListingID(42),
        changes: ListingChanges(status: .draft)
    )

    #expect(listing.id == ListingID(42))
    #expect(await transport.capturedRequests().map(\.httpMethod) == ["POST", "GET"])
}

@Test func collectionRatingHandlesNoContentAndRefetchesInstance() async throws {
    let (client, transport) = try makeClient(
        authentication: .personalToken("private-token"),
        responses: [
            StubResponse(statusCode: 204, data: Data()),
            StubResponse(
                json: #"{"releases":[{"instance_id":9,"folder_id":4,"rating":5,"basic_information":{"id":7,"title":"Release"}}]}"#
            ),
        ]
    )

    let item = try await client.user("example").collection.setRating(
        5,
        releaseID: ReleaseID(7),
        instanceID: CollectionInstanceID(9),
        folderID: FolderID(3),
        moveTo: FolderID(4)
    )

    #expect(item.folderID == FolderID(4))
    let requests = await transport.capturedRequests()
    #expect(requests.map(\.httpMethod) == ["POST", "GET"])
    let body = try #require(requests[0].httpBody)
    let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(object["rating"] as? Int == 5)
    #expect(object["folder_id"] as? Int == 4)
}

@Test func documentedMarketplaceMutationValuesEncode() throws {
    let listing = ListingChanges(
        estimateWeightAutomatically: true,
        estimateFormatQuantityAutomatically: true
    )
    let listingObject = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(listing)) as? [String: Any]
    )
    #expect(listingObject["weight"] as? String == "auto")
    #expect(listingObject["format_quantity"] as? String == "auto")

    let order = OrderChanges(tracking: OrderTrackingChanges(number: "TRACK-1", carrier: "DHL"))
    let orderObject = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(order)) as? [String: Any]
    )
    let tracking = try #require(orderObject["tracking"] as? [String: Any])
    #expect(tracking["number"] as? String == "TRACK-1")
    #expect(tracking["carrier"] as? String == "DHL")
}

@Test func orderMessageSupportsStatusAndCollectionSupportsSorting() async throws {
    let (client, transport) = try makeClient(
        authentication: .personalToken("private-token"),
        responses: [
            StubResponse(json: #"{"message":"On its way","type":"message"}"#),
            StubResponse(json: #"{"pagination":{"page":1,"pages":1,"per_page":50,"items":0,"urls":{}},"releases":[]}"#),
        ]
    )

    _ = try await client.marketplace.addMessage(
        "On its way",
        status: .shipped,
        to: OrderID("1-1")
    )
    _ = try await client.user("example").collection.items(
        in: FolderID(3),
        sort: .artist,
        order: .descending
    ).page()

    let requests = await transport.capturedRequests()
    let messageBody = try #require(requests[0].httpBody)
    let messageObject = try #require(JSONSerialization.jsonObject(with: messageBody) as? [String: Any])
    #expect(messageObject["message"] as? String == "On its way")
    #expect(messageObject["status"] as? String == "Shipped")
    let collectionURL = try #require(requests[1].url)
    let components = try #require(URLComponents(url: collectionURL, resolvingAgainstBaseURL: false))
    #expect(components.queryItems?.contains(URLQueryItem(name: "sort", value: "artist")) == true)
    #expect(components.queryItems?.contains(URLQueryItem(name: "sort_order", value: "desc")) == true)
}

@Test func csvEncoderEscapesQuotesCommasAndNewlines() {
    let csv = CSVEncoder.add([
        InventoryAddRow(
            releaseID: ReleaseID(1),
            mediaCondition: .mint,
            price: 10,
            comments: "A \"great\", copy\nIndeed"
        ),
    ])
    #expect(csv.contains(#""A ""great"", copy"#))
    #expect(csv.contains("copy\nIndeed\""))
    #expect(csv.hasPrefix("release_id,price,media_condition,sleeve_condition,comments,accept_offer"))
    #expect(csv.hasSuffix("\r\n"))
}

@Test func inventoryJobsUseLocationHeaderAndDocumentedTimestampKeys() async throws {
    let (client, transport) = try makeClient(
        authentication: .personalToken("token"),
        responses: [
            StubResponse(data: Data(), headers: ["Location": "https://api.discogs.com/inventory/export/599632"]),
            StubResponse(
                json: #"""
                {"id":599632,"status":"success","created_ts":"2018-09-27T12:50:39",
                "finished_ts":"2018-09-27T12:59:02",
                "download_url":"https://api.discogs.com/inventory/export/599632/download","filename":"export.csv"}
                """#
            ),
        ]
    )
    let id = try await client.inventory.startExport()
    #expect(id == ExportID(599_632))
    let export = try await client.inventory.export(id: id)
    #expect(export.created != nil)
    #expect(export.finished != nil)
    #expect(export.filename == "export.csv")
    #expect(await transport.capturedRequests().map(\.httpMethod) == ["POST", "GET"])
}

@Test func inventoryUploadUsesMultipartCSVAndLocationHeader() async throws {
    let (client, transport) = try makeClient(
        authentication: .personalToken("token"),
        responses: [StubResponse(
            data: Data(),
            headers: ["Location": "https://api.discogs.com/inventory/upload/119615"]
        )]
    )
    let id = try await client.inventory.uploadAdd([
        InventoryAddRow(
            releaseID: ReleaseID(123),
            mediaCondition: .mint,
            price: #require(Decimal(string: "1.50")),
            acceptOffer: true
        ),
    ])
    #expect(id == UploadID(119_615))
    let request = try #require(await transport.capturedRequests().first)
    #expect(request.url?.path == "/inventory/upload/add")
    #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
    let body = try String(data: #require(request.httpBody), encoding: .utf8)
    #expect(body?.contains("release_id,price,media_condition,sleeve_condition,comments,accept_offer") == true)
    #expect(body?.contains("123,1.5,Mint (M),,,Y") == true)
}

@Test func groupedSubmissionsFlattenIntoTypedCases() async throws {
    let json = #"""
    {
      "pagination":{"page":1,"pages":1,"per_page":50,"items":3,"urls":{}},
      "submissions":{
        "artists":[{"id":1,"name":"Artist"}],
        "labels":[{"id":2,"name":"Label"}],
        "releases":[{"id":3,"title":"Release","artists":[]}]
      }
    }
    """#
    let (client, _) = try makeClient(responses: [StubResponse(json: json)])
    var values: [Submission] = []
    for try await value in client.user("example").submissions() {
        values.append(value)
    }
    #expect(values.count == 3)
    guard case let .artist(artist) = values[0] else { Issue.record("Expected artist"); return }
    #expect(artist.id == ArtistID(1))
    guard case let .label(label) = values[1] else { Issue.record("Expected label"); return }
    #expect(label.id == LabelID(2))
    guard case let .release(release) = values[2] else { Issue.record("Expected release"); return }
    #expect(release.id == ReleaseID(3))
}

@Test func listDetailAcceptsDocumentedListIDAndURLKeys() throws {
    let json = #"{"list_id":2,"name":"A list","url":"https://www.discogs.com/lists/a-list/2","public":false,"items":[]}"#
    let list = try JSONDecoder.recordCatalog.decode(UserList.self, from: Data(json.utf8))
    #expect(list.id == 2)
    #expect(list.webURL?.host == "www.discogs.com")
}

@Test func documentedStatisticsAndCollectionValueShapesDecode() throws {
    let releaseStats = try JSONDecoder.recordCatalog.decode(
        ReleaseStatistics.self,
        from: Data(#"{"num_have":2315,"num_want":467}"#.utf8)
    )
    #expect(releaseStats.have == 2315)
    let marketplaceStats = try JSONDecoder.recordCatalog.decode(
        MarketplaceStatistics.self,
        from: Data(#"{"lowest_price":null,"num_for_sale":null,"blocked_from_sale":true}"#.utf8)
    )
    #expect(marketplaceStats.numberForSale == nil)
    let value = try JSONDecoder.recordCatalog.decode(
        CollectionValue.self,
        from: Data(#"{"minimum":"$75.50","median":"$100.25","maximum":"$250.00"}"#.utf8)
    )
    #expect(value.median == "$100.25")
}

@Test func signedImageDownloaderRejectsForeignHosts() async throws {
    let (client, transport) = try makeClient(
        authentication: .personalToken("token"),
        responses: []
    )
    await #expect(throws: RecordCatalogError.self) {
        _ = try await client.images.data(from: #require(URL(string: "https://example.com/image.jpg")))
    }
    #expect(await transport.capturedRequests().isEmpty)
}
