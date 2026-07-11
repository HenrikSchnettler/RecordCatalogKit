import Foundation

public struct ImageService: Sendable {
    let core: ClientCore

    public func download(_ image: ImageResource) async throws -> DownloadedImage {
        guard let url = image.resourceURL ?? image.uri else {
            throw RecordCatalogError.invalidRequest("The image resource has no downloadable URL.")
        }
        let data = try await core.sendData(
            RawEndpoint(absoluteURL: url, authentication: .authenticated)
        )
        return DownloadedImage(data: data, contentType: Self.contentType(for: data))
    }

    public func data(from url: URL) async throws -> Data {
        try await core.sendData(RawEndpoint(absoluteURL: url, authentication: .authenticated))
    }

    private static func contentType(for data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        if bytes.count >= 12,
           String(bytes: bytes[0 ..< 4], encoding: .ascii) == "RIFF",
           String(bytes: bytes[8 ..< 12], encoding: .ascii) == "WEBP"
        {
            return "image/webp"
        }
        return nil
    }
}
