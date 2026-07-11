# Collection management

```swift
let identity = try await client.identity()
let collection = client.user(identity.username).collection
let folders = try await collection.folders()

if let folder = folders.first {
    let addition = try await collection.add(ReleaseID(249504), to: folder.id)
    _ = try await collection.setRating(
        5,
        releaseID: ReleaseID(249504),
        instanceID: addition.instanceID,
        folderID: folder.id
    )
}
```
