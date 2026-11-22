//
//  NetworkService.swift
//  RogersMarketPlaceApp
//
//  Created by TINA JAINWAL on 20/11/26.
//

import Combine
import Foundation
import Network
import Observation

private struct DummyProductsResponse: Decodable {
    let products: [DummyProductDTO]
}

private struct DummyProductDTO: Codable {
    let id: Int?
    let title: String
    let thumbnail: String?
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid DummyJSON URL."
        case .invalidResponse: return "Invalid HTTP response."
        case .httpError(let code): return "HTTP error \(code) from DummyJSON."
        }
    }
}

protocol MarketplaceAPIProtocol {
    func fetchListings(limit: Int) async throws -> [Listing]
    func upsertListing(_ item: Listing) async throws -> Listing
    func sync(items: [Listing]) async throws -> [Listing]
}

protocol NetworkMonitoring: AnyObject {
    var isOnline: CurrentValueSubject<Bool, Never> { get }
    func isNetworkAvailable() async -> Bool
}

@MainActor
@Observable
final class NetworkMonitor: NetworkMonitoring {
    let isOnline = CurrentValueSubject<Bool, Never>(true)

    @ObservationIgnored
    private var monitor: NWPathMonitor?
    @ObservationIgnored
    private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored
    private var wakeContinuation: AsyncStream<Void>.Continuation?
    private let checkInterval: Duration = .seconds(15)

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        guard monitoringTask == nil else { return }

        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        wakeContinuation = continuation

        let nwMonitor = NWPathMonitor()
        nwMonitor.pathUpdateHandler = { _ in
            continuation.yield()
        }
        nwMonitor.start(queue: DispatchQueue(label: "com.rogersmarketplace.netmonitor"))
        self.monitor = nwMonitor

        monitoringTask = Task { [weak self] in
            await self?.check()
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in stream {
                        guard !Task.isCancelled else { return }
                        await self?.check()
                    }
                }
                group.addTask {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: self?.checkInterval ?? .seconds(15))
                        guard !Task.isCancelled else { return }
                        await self?.check()
                    }
                }
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil

        wakeContinuation?.finish()
        wakeContinuation = nil

        monitor?.cancel()
        monitor = nil
    }

    func isNetworkAvailable() async -> Bool {
        await check()
        return isOnline.value
    }

    private func check() async {
        let reachable = await Self.probeConnectivity()
        guard isOnline.value != reachable else { return }
        isOnline.send(reachable)
    }

    nonisolated private static func probeConnectivity() async -> Bool {
        guard let url = URL(string: "https://www.apple.com/library/test/success.html") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 3

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    deinit {
        monitoringTask?.cancel()
        wakeContinuation?.finish()
        monitor?.cancel()
    }
}

final class DummyJSONAPIService: MarketplaceAPIProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        baseURL: URL = URL(string: "https://dummyjson.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchListings(limit: Int = 0) async throws -> [Listing] {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("products"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let request = URLRequest(url: url, timeoutInterval: 20)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        let decoded = try decoder.decode(DummyProductsResponse.self, from: data)
        let now = Date.now

        return decoded.products.map { dto in
            Listing(
                id: UUID(),
                remoteID: dto.id,
                title: dto.title,
                isFavorite: false,
                imageFilename: nil,
                remoteImageURL: dto.thumbnail,
                updatedAt: now,
                syncStatus: .synced
            )
        }
    }

    func upsertListing(_ item: Listing) async throws -> Listing {
        let endpoint: String
        let method: String

        if let remoteID = item.remoteID {
            endpoint = "products/\(remoteID)"
            method = "PUT"
        } else {
            endpoint = "products/add"
            method = "POST"
        }

        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = DummyProductDTO(
            id: item.remoteID,
            title: item.title,
            thumbnail: item.remoteImageURL
        )
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        let echo = try? decoder.decode(DummyProductDTO.self, from: data)

        return Listing(
            id: item.id,
            remoteID: item.remoteID ?? echo?.id,
            title: echo?.title ?? item.title,
            isFavorite: item.isFavorite,
            imageFilename: item.imageFilename,
            remoteImageURL: echo?.thumbnail ?? item.remoteImageURL,
            updatedAt: item.updatedAt,
            syncStatus: .synced
        )
    }

    func sync(items: [Listing]) async throws -> [Listing] {
        var syncedResults: [Listing] = []
        syncedResults.reserveCapacity(items.count)
        for item in items {
            let synced = try await upsertListing(item)
            syncedResults.append(synced)
        }
        return syncedResults
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}
