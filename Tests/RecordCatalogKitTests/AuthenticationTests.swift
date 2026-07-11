import Foundation
@testable import RecordCatalogKit
import Testing

@Test func oauthSignerProducesDeterministicPlaintextSignature() {
    let header = OAuthSigner.authorizationHeader(
        consumer: ConsumerCredentials(key: "consumer key", secret: "consumer/secret"),
        token: "access token",
        tokenSecret: "access&secret",
        verifier: "1234",
        nonce: "nonce",
        timestamp: 1_700_000_000
    )
    #expect(header.hasPrefix("OAuth "))
    #expect(header.contains(#"oauth_consumer_key="consumer%20key""#))
    #expect(header.contains(#"oauth_signature="consumer%2Fsecret%26access%26secret""#))
    #expect(header.contains(#"oauth_token="access%20token""#))
    #expect(header.contains(#"oauth_verifier="1234""#))
    #expect(!header.contains("consumer/secret"))
}

@Test func credentialDescriptionsAreRedacted() {
    let consumer = ConsumerCredentials(key: "public-key", secret: "consumer-secret")
    let access = OAuthAccessCredentials(token: "access-token", secret: "access-secret")
    let authentication = Authentication.oauth(consumer: consumer, access: access)
    let rendered = [String(describing: consumer), String(describing: access), String(describing: authentication)]
    #expect(rendered.allSatisfy { !$0.contains("consumer-secret") })
    #expect(rendered.allSatisfy { !$0.contains("access-secret") })
    #expect(rendered.allSatisfy { !$0.contains("access-token") })
}

@Test func oauthCoordinatorParsesRequestAndAccessTokens() async throws {
    let transport = MockTransport([
        StubResponse(data: Data("oauth_token=request&oauth_token_secret=requestSecret&oauth_callback_confirmed=true"
                .utf8)),
        StubResponse(data: Data("oauth_token=access&oauth_token_secret=accessSecret".utf8)),
    ])
    let coordinator = OAuthCoordinator(
        consumer: ConsumerCredentials(key: "key", secret: "secret"),
        userAgent: "RecordCatalogKitTests/1.0",
        transport: transport
    )
    let authorization = try await coordinator.requestAuthorization(callback: .outOfBand)
    #expect(authorization.requestToken.token == "request")
    #expect(authorization.authorizationURL.absoluteString.contains("oauth_token=request"))
    let access = try await coordinator.exchange(authorization.requestToken, verifier: "1234")
    #expect(access.token == "access")
    let requests = await transport.capturedRequests()
    #expect(requests.map(\.httpMethod) == ["GET", "POST"])
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization")?.hasPrefix("OAuth ") == true })
}
