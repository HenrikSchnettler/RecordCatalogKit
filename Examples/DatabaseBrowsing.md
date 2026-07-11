# Database browsing

```swift
import RecordCatalogKit

let client = try RecordCatalogClient(
    configuration: .init(
        userAgent: "Example/1.0 +https://example.com",
        authentication: .consumerCredentials(key: key, secret: secret)
    )
)

let artist = try await client.database.artist(id: ArtistID(108713))
for try await release in client.database.artistReleases(for: artist.id) {
    print(release.title)
}
```
