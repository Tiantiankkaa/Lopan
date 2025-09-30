//
//  CloudProvider.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import Foundation

// MARK: - Cloud Provider Protocol

protocol CloudProvider: Sendable {
    func get<T: Codable>(endpoint: String, type: T.Type) async throws -> CloudResponse<T>
    func post<T: Codable, R: Codable>(endpoint: String, body: T, responseType: R.Type) async throws -> CloudResponse<R>
    func put<T: Codable, R: Codable>(endpoint: String, body: T, responseType: R.Type) async throws -> CloudResponse<R>
    func delete(endpoint: String) async throws -> CloudResponse<EmptyResponse>
    func getPaginated<T: Codable>(endpoint: String, type: T.Type, page: Int, pageSize: Int) async throws -> CloudPaginatedResponse<T>
}

// MARK: - HTTP Cloud Provider Implementation

final class HTTPCloudProvider: CloudProvider, Sendable {
    private let baseURL: String
    private let authenticationService: AuthenticationService?

    // PHASE 2: Lazy connection pooling - only create session when first network call is made
    private lazy var session: URLSession = {
        print("🔄 CloudProvider: Initializing URLSession lazily...")
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 5 // Connection pool: max 5 concurrent
        config.requestCachePolicy = .returnCacheDataElseLoad // Use cache when available
        return URLSession(configuration: config)
    }()

    // Decoders/encoders are lightweight, but still lazy for consistency
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(baseURL: String, authenticationService: AuthenticationService? = nil) {
        self.baseURL = baseURL
        self.authenticationService = authenticationService
        print("🎯 CloudProvider: Initialized with lazy connection pooling")
    }
    
    // MARK: - Private Helper Methods
    
    private func createRequest(url: URL, method: String) async -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add authentication headers if available
        if let authService = authenticationService {
            await MainActor.run {
                if let currentUser = authService.currentUser {
                    request.addValue("Bearer \(currentUser.id)", forHTTPHeaderField: "Authorization")
                    request.addValue(currentUser.id, forHTTPHeaderField: "X-User-ID")
                }
            }
        }
        
        return request
    }
    
    private func handleHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RepositoryError.connectionFailed("Invalid response type")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            break
        case 400:
            throw RepositoryError.invalidInput("Bad request")
        case 401:
            throw RepositoryError.authenticationFailed("Unauthorized")
        case 403:
            throw RepositoryError.authenticationFailed("Forbidden")
        case 404:
            throw RepositoryError.notFound("Resource not found")
        case 409:
            throw RepositoryError.conflictDetected("Resource conflict")
        case 429:
            throw RepositoryError.rateLimited("Too many requests")
        case 500...599:
            throw RepositoryError.serverError("Server error: \(httpResponse.statusCode)")
        default:
            throw RepositoryError.connectionFailed("HTTP \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - CloudProvider Methods
    
    func get<T: Codable>(endpoint: String, type: T.Type) async throws -> CloudResponse<T> {
        guard let url = URL(string: baseURL + endpoint) else {
            throw RepositoryError.invalidInput("Invalid URL: \(baseURL + endpoint)")
        }
        
        let request = await createRequest(url: url, method: "GET")
        
        do {
            let (data, response) = try await session.data(for: request)
            try handleHTTPResponse(response)
            
            let cloudResponse = try decoder.decode(CloudResponse<T>.self, from: data)
            return cloudResponse
        } catch let error as DecodingError {
            throw RepositoryError.invalidInput("Failed to decode response: \(error.localizedDescription)")
        } catch let error as URLError {
            throw RepositoryError.connectionFailed("Network error: \(error.localizedDescription)")
        }
    }
    
    func post<T: Codable, R: Codable>(endpoint: String, body: T, responseType: R.Type) async throws -> CloudResponse<R> {
        guard let url = URL(string: baseURL + endpoint) else {
            throw RepositoryError.invalidInput("Invalid URL: \(baseURL + endpoint)")
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        do {
            let bodyData = try encoder.encode(body)
            request.httpBody = bodyData
            request.addValue("\(bodyData.count)", forHTTPHeaderField: "Content-Length")
        } catch {
            throw RepositoryError.invalidInput("Failed to encode request body: \(error.localizedDescription)")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            try handleHTTPResponse(response)
            
            let cloudResponse = try decoder.decode(CloudResponse<R>.self, from: data)
            return cloudResponse
        } catch let error as DecodingError {
            throw RepositoryError.invalidInput("Failed to decode response: \(error.localizedDescription)")
        } catch let error as URLError {
            throw RepositoryError.connectionFailed("Network error: \(error.localizedDescription)")
        }
    }
    
    func put<T: Codable, R: Codable>(endpoint: String, body: T, responseType: R.Type) async throws -> CloudResponse<R> {
        guard let url = URL(string: baseURL + endpoint) else {
            throw RepositoryError.invalidInput("Invalid URL: \(baseURL + endpoint)")
        }
        
        var request = await createRequest(url: url, method: "PUT")
        
        do {
            let bodyData = try encoder.encode(body)
            request.httpBody = bodyData
            request.addValue("\(bodyData.count)", forHTTPHeaderField: "Content-Length")
        } catch {
            throw RepositoryError.invalidInput("Failed to encode request body: \(error.localizedDescription)")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            try handleHTTPResponse(response)
            
            let cloudResponse = try decoder.decode(CloudResponse<R>.self, from: data)
            return cloudResponse
        } catch let error as DecodingError {
            throw RepositoryError.invalidInput("Failed to decode response: \(error.localizedDescription)")
        } catch let error as URLError {
            throw RepositoryError.connectionFailed("Network error: \(error.localizedDescription)")
        }
    }
    
    func delete(endpoint: String) async throws -> CloudResponse<EmptyResponse> {
        guard let url = URL(string: baseURL + endpoint) else {
            throw RepositoryError.invalidInput("Invalid URL: \(baseURL + endpoint)")
        }
        
        let request = await createRequest(url: url, method: "DELETE")
        
        do {
            let (data, response) = try await session.data(for: request)
            try handleHTTPResponse(response)
            
            // Handle empty response body for DELETE requests
            if data.isEmpty {
                return CloudResponse<EmptyResponse>(
                    data: EmptyResponse(),
                    success: true,
                    error: nil,
                    timestamp: Date(),
                    requestId: UUID().uuidString
                )
            }
            
            let cloudResponse = try decoder.decode(CloudResponse<EmptyResponse>.self, from: data)
            return cloudResponse
        } catch let error as DecodingError {
            // If decoding fails for DELETE, assume success
            return CloudResponse<EmptyResponse>(
                data: EmptyResponse(),
                success: true,
                error: nil,
                timestamp: Date(),
                requestId: UUID().uuidString
            )
        } catch let error as URLError {
            throw RepositoryError.connectionFailed("Network error: \(error.localizedDescription)")
        }
    }
    
    func getPaginated<T: Codable>(endpoint: String, type: T.Type, page: Int, pageSize: Int) async throws -> CloudPaginatedResponse<T> {
        let separator = endpoint.contains("?") ? "&" : "?"
        let paginatedEndpoint = "\(endpoint)\(separator)page=\(page)&pageSize=\(pageSize)"
        
        guard let url = URL(string: baseURL + paginatedEndpoint) else {
            throw RepositoryError.invalidInput("Invalid URL: \(baseURL + paginatedEndpoint)")
        }
        
        let request = await createRequest(url: url, method: "GET")
        
        do {
            let (data, response) = try await session.data(for: request)
            try handleHTTPResponse(response)
            
            let cloudResponse = try decoder.decode(CloudPaginatedResponse<T>.self, from: data)
            return cloudResponse
        } catch let error as DecodingError {
            throw RepositoryError.invalidInput("Failed to decode paginated response: \(error.localizedDescription)")
        } catch let error as URLError {
            throw RepositoryError.connectionFailed("Network error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Health Check
    
    func healthCheck() async throws -> Bool {
        do {
            struct HealthResponse: Codable {
                let status: String
                let timestamp: Date
            }
            
            let response: CloudResponse<HealthResponse> = try await get(endpoint: "/health", type: HealthResponse.self)
            return response.success && response.data?.status == "healthy"
        } catch {
            return false
        }
    }
}

// MARK: - Mock Cloud Provider (for testing)

final class MockCloudProvider: CloudProvider, @unchecked Sendable {
    private var responses: [String: Any] = [:]
    private var shouldFail = false
    private var failureError: RepositoryError = .connectionFailed("Mock failure")
    
    func setMockResponse<T: Codable>(for endpoint: String, response: CloudResponse<T>) {
        responses[endpoint] = response
    }
    
    func setMockPaginatedResponse<T: Codable>(for endpoint: String, response: CloudPaginatedResponse<T>) {
        responses[endpoint] = response
    }
    
    func setShouldFail(_ shouldFail: Bool, with error: RepositoryError = .connectionFailed("Mock failure")) {
        self.shouldFail = shouldFail
        self.failureError = error
    }
    
    func get<T: Codable>(endpoint: String, type: T.Type) async throws -> CloudResponse<T> {
        if shouldFail {
            throw failureError
        }
        
        guard let response = responses[endpoint] as? CloudResponse<T> else {
            throw RepositoryError.notFound("Mock response not configured for endpoint: \(endpoint)")
        }
        
        return response
    }
    
    func post<T: Codable, R: Codable>(endpoint: String, body: T, responseType: R.Type) async throws -> CloudResponse<R> {
        if shouldFail {
            throw failureError
        }
        
        guard let response = responses[endpoint] as? CloudResponse<R> else {
            throw RepositoryError.notFound("Mock response not configured for endpoint: \(endpoint)")
        }
        
        return response
    }
    
    func put<T: Codable, R: Codable>(endpoint: String, body: T, responseType: R.Type) async throws -> CloudResponse<R> {
        if shouldFail {
            throw failureError
        }
        
        guard let response = responses[endpoint] as? CloudResponse<R> else {
            throw RepositoryError.notFound("Mock response not configured for endpoint: \(endpoint)")
        }
        
        return response
    }
    
    func delete(endpoint: String) async throws -> CloudResponse<EmptyResponse> {
        if shouldFail {
            throw failureError
        }
        
        return CloudResponse<EmptyResponse>(
            data: EmptyResponse(),
            success: true,
            error: nil,
            timestamp: Date(),
            requestId: UUID().uuidString
        )
    }
    
    func getPaginated<T: Codable>(endpoint: String, type: T.Type, page: Int, pageSize: Int) async throws -> CloudPaginatedResponse<T> {
        if shouldFail {
            throw failureError
        }
        
        guard let response = responses[endpoint] as? CloudPaginatedResponse<T> else {
            throw RepositoryError.notFound("Mock paginated response not configured for endpoint: \(endpoint)")
        }
        
        return response
    }
}

// MARK: - Cloud Provider Factory

enum CloudEnvironment {
    case development(baseURL: String)
    case staging(baseURL: String) 
    case production(baseURL: String)
    case mock
    
    var baseURL: String {
        switch self {
        case .development(let url), .staging(let url), .production(let url):
            return url
        case .mock:
            return "https://mock.lopan.app"
        }
    }
}

final class CloudProviderFactory {
    static func create(for environment: CloudEnvironment, authService: AuthenticationService? = nil) -> CloudProvider {
        switch environment {
        case .development(let baseURL), .staging(let baseURL), .production(let baseURL):
            return HTTPCloudProvider(baseURL: baseURL, authenticationService: authService)
        case .mock:
            return MockCloudProvider()
        }
    }
}