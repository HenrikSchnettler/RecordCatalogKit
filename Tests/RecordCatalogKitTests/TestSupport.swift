import Foundation
@testable import RecordCatalogKit

struct StubResponse: Sendable {
    let statusCode: Int
    let data: Data
    let headers: [String: String]

    init(statusCode: Int = 200, json: String = "{}", headers: [String: String] = [:]) {
        self.statusCode = statusCode
        data = Data(json.utf8)
        self.headers = headers
    }

    init(statusCode: Int = 200, data: Data, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
    }
}

actor MockTransport: HTTPTransport {
    private var responses: [StubResponse]
    private(set) var requests: [URLRequest] = []

    init(_ responses: [StubResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        let stub = responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        return (stub.data, response)
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }
}

func makeClient(
    authentication: Authentication = .anonymous,
    responses: [StubResponse]
) throws -> (RecordCatalogClient, MockTransport) {
    let transport = MockTransport(responses)
    let client = try RecordCatalogClient(
        configuration: .init(
            userAgent: "RecordCatalogKitTests/1.0",
            authentication: authentication,
            retryPolicy: .disabled
        ),
        transport: transport
    )
    return (client, transport)
}
