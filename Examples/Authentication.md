# OAuth authentication

```swift
import RecordCatalogKit

let consumer = ConsumerCredentials(key: consumerKey, secret: consumerSecret)
let coordinator = OAuthCoordinator(
    consumer: consumer,
    userAgent: "Example/1.0 +https://example.com"
)

let authorization = try await coordinator.requestAuthorization(
    callback: .url(URL(string: "example://oauth")!)
)

// Present authorization.authorizationURL, then exchange the callback verifier.
let access = try await coordinator.exchange(
    authorization.requestToken,
    verifier: verifier
)

let client = try RecordCatalogClient(
    configuration: .init(
        userAgent: "Example/1.0 +https://example.com",
        authentication: .oauth(consumer: consumer, access: access)
    )
)
```
