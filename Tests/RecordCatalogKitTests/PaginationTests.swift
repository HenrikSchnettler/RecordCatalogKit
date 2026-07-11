import Foundation
@testable import RecordCatalogKit
import Testing

@Test func paginatorLoadsEveryPageLazily() async throws {
    let page1 = #"""
    {
      "pagination":{"page":1,"pages":2,"per_page":2,"items":3,"urls":{"next":"https://api.discogs.com/database/search?page=2"}},
      "results":[{"id":1,"type":"release","title":"One","year":"2001"},{"id":2,"type":"master","title":"Two","year":2002}]
    }
    """#
    let page2 = #"{"pagination":{"page":2,"pages":2,"per_page":2,"items":3,"urls":{"prev":"https://api.discogs.com/database/search?page=1"}},"results":[{"id":3,"type":"artist","title":"Three"}]}"#
    let (client, transport) = try makeClient(
        authentication: .consumerCredentials(key: "key", secret: "secret"),
        responses: [StubResponse(json: page1), StubResponse(json: page2)]
    )

    let paginator = client.database.search(.init(query: "test"), pageSize: 2)
    #expect(await transport.capturedRequests().isEmpty)
    var values: [SearchResult] = []
    for try await value in paginator {
        values.append(value)
    }
    #expect(values.map(\.id) == [1, 2, 3])
    #expect(values.map(\.year) == [2001, 2002, nil])
    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    #expect(requests
        .compactMap {
            URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "page" })?
                .value
        } == [
            "1",
            "2",
        ])
}

@Test func paginatorValidatesPageSizeBeforeNetworking() async throws {
    let (client, transport) = try makeClient(
        authentication: .consumerCredentials(key: "key", secret: "secret"),
        responses: []
    )
    let paginator = client.database.search(.init(query: "test"), pageSize: 101)
    await #expect(throws: RecordCatalogError.self) {
        _ = try await paginator.page()
    }
    #expect(await transport.capturedRequests().isEmpty)
}
