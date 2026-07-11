import Foundation

public struct PageRequest: Sendable, Equatable, Codable {
    public var page: Int
    public var perPage: Int

    public init(page: Int = 1, perPage: Int = 50) {
        self.page = page
        self.perPage = perPage
    }

    func validated() throws -> Self {
        guard page >= 1 else {
            throw RecordCatalogError.invalidRequest("Page numbers must be at least 1.")
        }
        guard (1 ... 100).contains(perPage) else {
            throw RecordCatalogError.invalidRequest("Discogs page sizes must be between 1 and 100.")
        }
        return self
    }

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
        ]
    }
}

public struct PageMetadata: Sendable, Equatable, Decodable {
    public let page: Int
    public let pages: Int
    public let perPage: Int
    public let items: Int
    public let urls: PageURLs

    enum CodingKeys: String, CodingKey {
        case page, pages, items, urls
        case perPage = "per_page"
    }
}

public struct PageURLs: Sendable, Equatable, Decodable {
    public let first: URL?
    public let previous: URL?
    public let next: URL?
    public let last: URL?

    public init(first: URL? = nil, previous: URL? = nil, next: URL? = nil, last: URL? = nil) {
        self.first = first
        self.previous = previous
        self.next = next
        self.last = last
    }

    enum CodingKeys: String, CodingKey {
        case first, next, last
        case previous = "prev"
    }
}

public struct Page<Element: Sendable>: Sendable {
    public let items: [Element]
    public let metadata: PageMetadata

    public init(items: [Element], metadata: PageMetadata) {
        self.items = items
        self.metadata = metadata
    }
}

public struct Paginator<Element: Sendable>: AsyncSequence, Sendable {
    public typealias AsyncIterator = Iterator
    public typealias Failure = Error

    private let pageSize: Int
    private let loader: @Sendable (PageRequest) async throws -> Page<Element>

    init(pageSize: Int, loader: @escaping @Sendable (PageRequest) async throws -> Page<Element>) {
        self.pageSize = pageSize
        self.loader = loader
    }

    public func page(_ number: Int = 1) async throws -> Page<Element> {
        try await loader(PageRequest(page: number, perPage: pageSize).validated())
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(pageSize: pageSize, loader: loader)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private let pageSize: Int
        private let loader: @Sendable (PageRequest) async throws -> Page<Element>
        private var nextPage = 1
        private var buffer: ArraySlice<Element> = []
        private var finished = false

        init(pageSize: Int, loader: @escaping @Sendable (PageRequest) async throws -> Page<Element>) {
            self.pageSize = pageSize
            self.loader = loader
        }

        public mutating func next() async throws -> Element? {
            try Task.checkCancellation()
            if let value = buffer.popFirst() {
                return value
            }
            guard !finished else { return nil }
            let page = try await loader(PageRequest(page: nextPage, perPage: pageSize).validated())
            buffer = ArraySlice(page.items)
            finished = page.items.isEmpty || nextPage >= Swift.max(1, page.metadata.pages)
            nextPage += 1
            if let value = buffer.popFirst() {
                return value
            }
            return nil
        }
    }
}
