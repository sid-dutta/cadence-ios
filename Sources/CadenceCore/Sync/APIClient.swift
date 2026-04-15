import Foundation

public struct AuthCredentials: Codable, Sendable {
    public var email: String
    public var password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct TokenResponse: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String
}

public struct UserProfile: Codable, Sendable, Equatable {
    public let id: Int
    public let email: String
    public let createdAt: Date
}

public struct SyncRequest: Codable, Sendable {
    public var since: Date?
    public var workouts: [Workout]
    public var runs: [Run]

    public init(since: Date?, workouts: [Workout], runs: [Run]) {
        self.since = since
        self.workouts = workouts
        self.runs = runs
    }
}

public struct SyncResponse: Codable, Sendable {
    public let serverTime: Date
    public let workouts: [Workout]
    public let runs: [Run]
}

public enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case http(status: Int, message: String)
    case decoding(String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "The server URL is not valid."
        case .invalidResponse: "The server returned an unexpected response."
        case .unauthorized: "Your session has expired. Please sign in again."
        case .http(let status, let message): "Server error \(status): \(message)"
        case .decoding(let detail): "Couldn't read the server's response: \(detail)"
        case .transport(let detail): detail
        }
    }
}

private struct ErrorEnvelope: Decodable {
    let detail: String
}

public actor CadenceAPIClient {
    public let baseURL: URL
    private let session: URLSession
    private var token: String?

    public init(baseURL: URL, session: URLSession = .shared, token: String? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.token = token
    }

    public func setToken(_ token: String?) {
        self.token = token
    }

    public func register(_ credentials: AuthCredentials) async throws -> TokenResponse {
        let response: TokenResponse = try await send("auth/register", method: "POST", body: credentials)
        token = response.accessToken
        return response
    }

    public func login(_ credentials: AuthCredentials) async throws -> TokenResponse {
        let response: TokenResponse = try await send("auth/login", method: "POST", body: credentials)
        token = response.accessToken
        return response
    }

    public func me() async throws -> UserProfile {
        try await send("auth/me", method: "GET", body: Optional<Never>.none)
    }

    public func sync(_ request: SyncRequest) async throws -> SyncResponse {
        try await send("sync", method: "POST", body: request)
    }

    public func health() async throws -> Bool {
        struct Health: Decodable { let status: String }
        let result: Health = try await send("health", method: "GET", body: Optional<Never>.none)
        return result.status == "ok"
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONCoding.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try JSONCoding.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        case 401:
            throw APIError.unauthorized
        default:
            let message = (try? JSONCoding.decode(ErrorEnvelope.self, from: data))?.detail
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw APIError.http(status: http.statusCode, message: message)
        }
    }
}
