# RecordCatalogKit

`RecordCatalogKit` is an asynchronous, concurrency-safe Swift SDK for the
[Discogs API v2](https://www.discogs.com/developers). It provides typed models,
OAuth 1.0a and token authentication, lazy pagination, rate-limit metadata,
bounded retries, marketplace operations, and inventory CSV workflows without
third-party dependencies.

> This application uses Discogs' API but is not affiliated with, sponsored or
> endorsed by Discogs. “Discogs” is a trademark of Zink Media, LLC.

## Requirements

- Swift 6.2 or newer
- iOS 26 or newer
- macOS 13 or newer for command-line development and tests

## Installation

Add this repository in Xcode or declare it in `Package.swift`:

```swift
.package(url: "https://github.com/HenrikSchnettler/RecordCatalogKit.git", from: "1.0.0")
```

Then add `RecordCatalogKit` to the application target.

## Quick start

Discogs requires every client to supply a unique User-Agent. Prefer a value
that includes the application name, version, and a contact URL.

```swift
import RecordCatalogKit

let client = try RecordCatalogClient(
    configuration: .init(
        userAgent: "MyRecordApp/1.0 +https://example.com"
    )
)

let release = try await client.database.release(id: ReleaseID(249504))
print(release.title)
```

## Authentication

### Consumer credentials

Consumer credentials increase the documented request limit and enable image
URLs, but they do not act as a Discogs user.

```swift
let client = try RecordCatalogClient(
    configuration: .init(
        userAgent: "MyRecordApp/1.0 +https://example.com",
        authentication: .consumerCredentials(
            key: consumerKey,
            secret: consumerSecret
        )
    )
)
```

### Personal token

Use a personal token for software that accesses only the token owner's account:

```swift
let client = try RecordCatalogClient(
    configuration: .init(
        userAgent: "MyPrivateTool/1.0 +https://example.com",
        authentication: .personalToken(personalToken)
    )
)

let identity = try await client.identity()
let folders = try await client.user(identity.username).collection.folders()
```

### OAuth 1.0a

`OAuthCoordinator` performs the protocol exchange but deliberately does not
present UI or persist secrets. Present `authorizationURL` with
`ASWebAuthenticationSession`, then store access credentials in Keychain.

```swift
let consumer = ConsumerCredentials(key: consumerKey, secret: consumerSecret)
let oauth = OAuthCoordinator(
    consumer: consumer,
    userAgent: "MyRecordApp/1.0 +https://example.com"
)

let request = try await oauth.requestAuthorization(
    callback: .url(URL(string: "my-record-app://oauth")!)
)

// Present request.authorizationURL and read oauth_verifier from the callback.
let access = try await oauth.exchange(request.requestToken, verifier: verifier)

let client = try RecordCatalogClient(
    configuration: .init(
        userAgent: "MyRecordApp/1.0 +https://example.com",
        authentication: .oauth(consumer: consumer, access: access)
    )
)
```

Access tokens do not have a refresh flow. They remain valid until revoked.
Never log or serialize credential values.

## Pagination

Paginated endpoints return a reusable `Paginator<Element>`. It is lazy and
conforms to `AsyncSequence`:

```swift
let search = client.database.search(
    .init(query: "Nevermind", type: .release, artist: "Nirvana"),
    pageSize: 100
)

for try await result in search {
    print(result.title)
}
```

Fetch a specific page when UI-level pagination is preferable:

```swift
let page = try await search.page(3)
print(page.metadata.pages)
print(page.items)
```

Discogs permits page sizes from 1 through 100. Invalid values fail before a
network request is sent.

## Errors and rate limits

```swift
do {
    let order = try await client.marketplace.order(id: OrderID("123-1"))
    print(order.status.rawValue)
} catch RecordCatalogError.authenticationRequired {
    // Configure a personal token or OAuth access credentials.
} catch RecordCatalogError.rateLimited(let retryAfter, let status) {
    print(retryAfter as Any, status as Any)
} catch RecordCatalogError.api(let error) {
    print(error.statusCode, error.message as Any)
}

if let limit = await client.latestRateLimitStatus() {
    print("\(limit.remaining) of \(limit.limit) requests remain")
}
```

The client reads `X-Discogs-Ratelimit`, `X-Discogs-Ratelimit-Used`, and
`X-Discogs-Ratelimit-Remaining`. GET requests retry bounded transient failures
and 429 responses. Mutating requests are never replayed automatically.

## Endpoint coverage

| Area | Coverage |
| --- | --- |
| Database | Release, release ratings, community rating, statistics, master releases and versions, artists and releases, labels and releases, database search |
| Images | Authenticated downloads of signed Discogs image URLs |
| Identity and profiles | Identity, profile get/edit, submissions, contributions |
| Collections | Folders, releases by folder/release, additions, ratings, deletion, custom fields, collection value |
| Wantlists | List, add, edit, remove |
| User lists | User lists and list details |
| Marketplace | Inventory, listings CRUD, orders get/list/edit, order messages, fees, price suggestions, marketplace statistics |
| Inventory export | Create, list, inspect, download to `Data` or a caller-owned URL |
| Inventory upload | Typed CSV add/change/delete, list and inspect upload jobs |
| Authentication | Anonymous, consumer key/secret, personal token, OAuth request/access token exchange |

## Model behavior

- Money uses `Decimal`, not binary floating point.
- IDs use domain-specific wrappers such as `ReleaseID` and `ListingID`.
- Server-extensible values such as currencies, conditions, and statuses preserve
  unknown raw values instead of failing decoding.
- Release years accept documented number or numeric-string shapes.
- Partial release dates preserve their original representation in `ReleaseDate`.
- Signed image URLs are used exactly as returned by Discogs.

## Compliance and caching

The SDK does not persist or cache API responses. Applications using Discogs
data must review the current [API Terms of Use](https://support.discogs.com/hc/en-us/articles/360009334593-API-Terms-of-Use),
including restricted-data handling, cache/display-age limits, the required
unaffiliated-application notice, and “Data provided by Discogs” attribution with
a link to the corresponding Discogs page. Relevant models expose source web
URLs when the API supplies them.

## Known gaps and deliberate boundaries

- Only endpoints documented in Discogs API v2 are included; undocumented web
  and mobile endpoints are intentionally excluded.
- The SDK does not present authentication UI, store credentials, or integrate
  with Keychain. Those are application responsibilities.
- OAuth uses Discogs' documented `PLAINTEXT` signature method over HTTPS.
- There is no Discogs sandbox documented. Tests use synthetic mocked responses;
  destructive live marketplace and account tests are not included.
- The local limiter cannot account perfectly for other processes sharing the
  same public IP and credentials. Server headers and 429 responses remain
  authoritative.
- Response models ignore unknown object fields while preserving unknown values
  in server-extensible string vocabularies.
- Inventory export downloads are materialized as `Data` before an optional
  atomic write. Applications handling exceptionally large exports should
  account for the temporary memory cost.
- The API documentation includes legacy URLs and inconsistent optional fields.
  Decoding is tolerant for optional peripheral fields but remains strict for
  required identifiers and primary names/titles.

## Development

```sh
brew install swiftformat swiftlint
./Scripts/format.sh
./Scripts/lint.sh
swift build
swift test
```

All tests use mocked transports and synthetic data; no Discogs credentials are
required.

The `Quality` GitHub Actions workflow runs formatting checks, strict SwiftLint,
tests, and a release build on every push, pull request, and merge queue run.

## Releases

Releases use two manually dispatched workflows:

1. Run **Release Dry Run** with a semantic version such as `1.0.0`. It performs
   every release gate and uploads the prospective source archive without creating
   a tag or release.
2. After the dry run passes, dispatch **Release** from `main` with the same
   version and confirmation text `release VERSION`. It reruns all gates, creates
   tag `vVERSION`, and publishes a GitHub release with generated notes and a
   source archive.

Because Swift Package Manager resolves version tags, the resulting GitHub release
is immediately consumable through Xcode or `Package.swift`.

## License

RecordCatalogKit source code is available under the MIT License. Discogs API
data and trademarks remain subject to Discogs' own terms and policies.
