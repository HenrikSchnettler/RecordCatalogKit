# Marketplace

```swift
let listing = try await client.marketplace.createListing(
    ListingDraft(
        releaseID: ReleaseID(249504),
        condition: .nearMint,
        price: Decimal(string: "12.50")!,
        sleeveCondition: .veryGoodPlus,
        allowOffers: true
    )
)

let current = try await client.marketplace.listing(id: listing.listingID)
print(current.price)
```
