//
//  MarketplaceVM.swift
//  RogersMarketPlaceApp
//
//  Created by TINA JAINWAL on 19/11/26.
//

import Combine
import Foundation
import UIKit

@MainActor
final class MarketplaceVM: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var searchText = ""
    @Published var isOnline = true
    
    private let storage: ListingStorageProtocol
    private let marketplaceAPIProtocol: MarketplaceAPIProtocol
    private let networkMonitoring: NetworkMonitoring
    private var cancellables = Set<AnyCancellable>()
    
    init(
        storage: ListingStorageProtocol,
        marketplaceAPIProtocol: MarketplaceAPIProtocol,
        networkMonitoring: NetworkMonitoring,
    ) {
        self.storage = storage
        self.marketplaceAPIProtocol = marketplaceAPIProtocol
        self.networkMonitoring = networkMonitoring
        
        listings = storage.load()
        if listings.isEmpty { seed200Items() }
        
        networkMonitoring.isOnline
            .removeDuplicates()
            .sink { [weak self] online in
                self?.isOnline = online
                if online { Task { await self?.syncNow() } }
            }
            .store(in: &self.cancellables)
    }
    
    static func makeDefault() -> MarketplaceVM {
        MarketplaceVM(
            storage: LocalStorage(),
            marketplaceAPIProtocol: MockAPIService(),
            networkMonitoring: NetworkMonitor()
        )
    }
    
    var filteredListings: [Listing] {
        guard !searchText.isEmpty else { return listings }
        let result = listings.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return result
    }
    
    // Create offline or online
    func addListing(title: String, image: UIImage?) {
        let filename = image.flatMap { ImageStore.shared.saveImage($0) }
        let newItem = Listing(
            id: UUID(),
            title: title,
            isFavorite: false,
            imageFilename: filename,
            updatedAt: .now,
            syncStatus: .pending
        )
        listings.insert(newItem, at: 0)
        persistAndSync()
    }
    
    // Toggle favorite offline or online
    func toggleFavorite(_ item: Listing) {
        guard let idx = listings.firstIndex(where: { $0.id == item.id }) else { return }
        listings[idx].isFavorite.toggle()
        listings[idx].updatedAt = .now
        listings[idx].syncStatus = .pending
        persistAndSync()
    }
    
    private func persistAndSync() {
        storage.save(listings)
        if isOnline { Task { await syncNow() } }
    }
    
    func syncNow() async {
        let pending = listings.filter { $0.syncStatus == .pending }
        if let remoteItems = try? await marketplaceAPIProtocol.sync(items: pending) {
            mergeRemote(remoteItems)
            storage.save(listings)
        }
    }
    
    func mergeRemote(_ remoteItems: [Listing]) {
        for remote in remoteItems {
            if let idx = listings.firstIndex(where: { $0.id == remote.id }) {
                if remote.updatedAt >= listings[idx].updatedAt {
                    listings[idx] = remote
                }
            } else {
                listings.append(remote)
            }
        }
        listings.sort { $0.updatedAt > $1.updatedAt }
    }
    
    private func seed200Items() {
        listings = (1...200).map { i in
            Listing(id: UUID(), title: "Marketplace Item #\(i)",
                    isFavorite: false, imageFilename: nil, updatedAt: .now, syncStatus: .synced)
        }
        storage.save(listings)
    }
}
