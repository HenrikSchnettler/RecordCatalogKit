import Foundation
@testable import RecordCatalogKit
import Testing

@Test func configurationRequiresUserAgent() {
    #expect(throws: RecordCatalogError.self) {
        _ = try RecordCatalogClient(configuration: .init(userAgent: ""))
    }
}

@Test func requestIncludesHeadersAndCapturesRateLimit() async throws {
    let (client, transport) = try makeClient(
        authentication: .consumerCredentials(key: "key", secret: "secret"),
        responses: [StubResponse(
            json: #"{"id":249504,"title":"Test","year":"1987","artists":[]}"#,
            headers: [
                "X-Discogs-Ratelimit": "60",
                "X-Discogs-Ratelimit-Used": "4",
                "X-Discogs-Ratelimit-Remaining": "56",
            ]
        )]
    )

    let release = try await client.database.release(id: ReleaseID(249_504), currency: .eur)
    #expect(release.id == ReleaseID(249_504))
    #expect(release.year == 1987)

    let request = try #require(await transport.capturedRequests().first)
    #expect(request.httpMethod == "GET")
    #expect(request.url?.path == "/releases/249504")
    #expect(try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first?
        .value == "EUR")
    #expect(request.value(forHTTPHeaderField: "User-Agent") == "RecordCatalogKitTests/1.0")
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.discogs.v2.discogs+json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Discogs key=key, secret=secret")
    #expect(await client.latestRateLimitStatus() == RateLimitStatus(limit: 60, used: 4, remaining: 56))
}

@Test func apiErrorPreservesStatusAndMessage() async throws {
    let (client, _) = try makeClient(responses: [StubResponse(
        statusCode: 404,
        json: #"{"message":"Release not found."}"#
    )])
    do {
        _ = try await client.database.release(id: ReleaseID(1))
        Issue.record("Expected an API error")
    } catch let RecordCatalogError.api(error) {
        #expect(error.statusCode == 404)
        #expect(error.message == "Release not found.")
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test func userEndpointRejectsConsumerOnlyAuthenticationLocally() async throws {
    let (client, transport) = try makeClient(
        authentication: .consumerCredentials(key: "key", secret: "secret"),
        responses: []
    )
    await #expect(throws: RecordCatalogError.self) {
        _ = try await client.identity()
    }
    #expect(await transport.capturedRequests().isEmpty)
}

@Test func mutationIsNotRetried() async throws {
    let transport = MockTransport([
        StubResponse(statusCode: 503, json: #"{"message":"Unavailable"}"#),
        StubResponse(json: #"{"listing_id":42}"#),
    ])
    let client = try RecordCatalogClient(
        configuration: .init(
            userAgent: "RecordCatalogKitTests/1.0",
            authentication: .personalToken("token"),
            retryPolicy: RetryPolicy(maximumRetryCount: 3)
        ),
        transport: transport
    )
    await #expect(throws: RecordCatalogError.self) {
        _ = try await client.marketplace.createListing(
            ListingDraft(releaseID: ReleaseID(1), condition: .mint, price: 10)
        )
    }
    #expect(await transport.capturedRequests().count == 1)
}
