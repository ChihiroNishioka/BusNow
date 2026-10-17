import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPRequest: Sendable, Equatable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?

    public init(url: URL, method: String = "GET", headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable, Equatable {
    public var status: Int
    public var body: Data
    public var url: URL
    public var headers: [String: String]

    public init(status: Int, body: Data, url: URL, headers: [String: String] = [:]) {
        self.status = status
        self.body = body
        self.url = url
        self.headers = headers
    }
}

public struct HTTPClient: Sendable {
    private let _fetch: @Sendable (HTTPRequest) async throws -> HTTPResponse

    public init(_ fetch: @escaping @Sendable (HTTPRequest) async throws -> HTTPResponse) {
        self._fetch = fetch
    }

    public func fetch(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await _fetch(request)
    }
}

public enum HTTP {
    public static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    public static let requestTimeout: TimeInterval = 15

    public static func fetchText(_ client: HTTPClient, _ url: URL) async throws -> String {
        let response = try await client.fetch(HTTPRequest(url: url))
        try validate(response)
        return decodePage(response.body)
    }

    public static func fetchFormJSON<T: Decodable>(
        _ client: HTTPClient,
        _ url: URL,
        fields: [(String, String)],
        as type: T.Type
    ) async throws -> T {
        var request = HTTPRequest(url: url, method: "POST", body: formBody(fields))
        request.headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
        let response = try await client.fetch(request)
        try validate(response)
        do {
            return try JSONDecoder().decode(T.self, from: response.body)
        } catch {
            throw BusTransportError("公式ページの形式が読めませんでした")
        }
    }

    public static func validate(_ response: HTTPResponse) throws {
        guard (200...299).contains(response.status) else {
            throw BusTransportError("HTTP \(response.status) \(response.url.absoluteString)")
        }
    }

    public static func formBody(_ fields: [(String, String)]) -> Data {
        let text = fields.map { key, value in
            "\(urlForm(key))=\(urlForm(value))"
        }.joined(separator: "&")
        return Data(text.utf8)
    }

    public static func urlForm(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return encoded.replacingOccurrences(of: "%20", with: "+")
    }

    public static func urlRequest(for request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = requestTimeout
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        urlRequest.setValue("text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        urlRequest.setValue("ja,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        return urlRequest
    }

    public static func sessionClient(_ session: URLSession = configuredSession()) -> HTTPClient {
        HTTPClient { request in
            let urlRequest = urlRequest(for: request)
            do {
                let (data, response) = try await session.data(for: urlRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw BusTransportError("公式ページから取れませんでした")
                }
                var headers: [String: String] = [:]
                for (key, value) in http.allHeaderFields {
                    headers[String(describing: key)] = String(describing: value)
                }
                return HTTPResponse(status: http.statusCode, body: data, url: request.url, headers: headers)
            } catch let error as BusTransportError {
                throw error
            } catch let error as URLError {
                throw map(error)
            } catch {
                let text = error.localizedDescription
                if containsMatch(text, pattern: "timeout|timed out", caseInsensitive: true) {
                    throw BusTransportError("timeout")
                }
                throw BusTransportError(BoardCopy.offline)
            }
        }
    }

    public static func configuredSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept-Language": "ja,en;q=0.8",
        ]
        return URLSession(configuration: configuration)
    }

    static func map(_ error: URLError) -> BusTransportError {
        switch error.code {
        case .timedOut:
            return BusTransportError("timeout")
        case .cancelled:
            return BusTransportError("abort")
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .internationalRoamingOff:
            return BusTransportError(BoardCopy.offline)
        default:
            let text = error.localizedDescription
            if containsMatch(text, pattern: "timeout|timed out", caseInsensitive: true) {
                return BusTransportError("timeout")
            }
            return BusTransportError(BoardCopy.offline)
        }
    }
}
