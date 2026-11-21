//
//  NetworkService.swift
//  RogersMarketPlaceApp
//
//  Created by TINA JAINWAL on 20/11/26.
//

import Combine
import Network
import Foundation

protocol MarketplaceAPIProtocol {
    func sync(items: [Listing]) async throws -> [Listing]
}

protocol NetworkMonitoring {
    var isOnline: CurrentValueSubject<Bool, Never> { get }
}

final class NetworkMonitor: NetworkMonitoring {
    let isOnline = CurrentValueSubject<Bool, Never>(true)
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.isOnline.send(path.status == .satisfied) }
        }
        monitor.start(queue: DispatchQueue(label: "NetMonitor"))
    }
}

actor MockAPIService: MarketplaceAPIProtocol {
    private var serverDB: [UUID: Listing] = [:]

    func sync(items: [Listing]) async throws -> [Listing] {
        try await Task.sleep(for: .milliseconds(400))
        for var item in items {
            item.syncStatus = .synced
            if let existing = serverDB[item.id], existing.updatedAt > item.updatedAt {
                continue
            }
            serverDB[item.id] = item
        }
        return Array(serverDB.values)
    }
}
