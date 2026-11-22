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
    private var hasStartedInitialLoad = false

    init(
        storage: ListingStorageProtocol,
        marketplaceAPIProtocol: MarketplaceAPIProtocol,
        networkMonitoring: NetworkMonitoring
    ) {
        self.storage = storage
        self.marketplaceAPIProtocol = marketplaceAPIProtocol
        self.networkMonitoring = networkMonitoring

        let initialOnline = networkMonitoring.isOnline.value
        self.isOnline = initialOnline

        let saved = storage.load()
        listings = saved.filter { !$0.title.hasPrefix("Marketplace Item #") }
        sortListings()

        if listings.isEmpty && !initialOnline {
            seedOfflineItems()
        }

        networkMonitoring.isOnline
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] online in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online

                if online && (!self.hasStartedInitialLoad || wasOffline) {
                    self.hasStartedInitialLoad = true
                    Task { await self.refreshProducts() }
                }
            }
            .store(in: &self.cancellables)
    }

    static func makeDefault() -> MarketplaceVM {
        MarketplaceVM(
            storage: LocalStorage(),
            marketplaceAPIProtocol: DummyJSONAPIService(),
            networkMonitoring: NetworkMonitor()
        )
    }

    var filteredListings: [Listing] {
        guard !searchText.isEmpty else { return listings }
        return listings.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    func addListing(title: String, image: UIImage?) {
        let filename = image.flatMap { ImageStore.shared.saveImage($0) }
        let newItem = Listing(
            id: UUID(),
            remoteID: nil,
            title: title,
            isFavorite: false,
            imageFilename: filename,
            remoteImageURL: nil,
            updatedAt: .now,
            syncStatus: .pending
        )
        listings.insert(newItem, at: 0)
        sortListings()
        persistAndSync(item: newItem)
    }

    func toggleFavorite(_ item: Listing) {
        guard let idx = listings.firstIndex(where: { $0.id == item.id }) else { return }
        listings[idx].isFavorite.toggle()
        listings[idx].updatedAt = .now
        listings[idx].syncStatus = .pending

        let updatedItem = listings[idx]
        sortListings()
        persistAndSync(item: updatedItem)
    }

    func syncItem(_ item: Listing) async {
        guard isOnline else { return }
        do {
            let synced = try await marketplaceAPIProtocol.upsertListing(item)
            mergeRemote([synced])
            storage.save(listings)
        } catch {
            storage.save(listings)
        }
    }

    func refreshProducts() async {
        let pending = listings.filter { $0.syncStatus == .pending }
        if !pending.isEmpty, let syncedPending = try? await marketplaceAPIProtocol.sync(items: pending) {
            mergeRemote(syncedPending)
            storage.save(listings)
        }

        if let remoteProducts = try? await marketplaceAPIProtocol.fetchListings(limit: 0) {
            mergeFetchedProducts(remoteProducts)
            storage.save(listings)
        }
    }

    func mergeRemote(_ remoteItems: [Listing]) {
        for remote in remoteItems {
            if let idx = listings.firstIndex(where: { $0.id == remote.id }) {
                var merged = remote
                merged.isFavorite = listings[idx].isFavorite
                if merged.updatedAt >= listings[idx].updatedAt {
                    listings[idx] = merged
                }
            } else {
                listings.append(remote)
            }
        }
        sortListings()
    }

    private func sortListings() {
        listings.sort {
            if $0.isFavorite != $1.isFavorite {
                return $0.isFavorite && !$1.isFavorite
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func persistAndSync(item: Listing) {
        storage.save(listings)
        if isOnline {
            Task { await syncItem(item) }
        }
    }

    private func mergeFetchedProducts(_ fetched: [Listing]) {
        listings.removeAll {
            $0.title.hasPrefix("Marketplace Item #") && $0.remoteID == nil && $0.syncStatus == .synced
        }

        for i in listings.indices {
            if let remoteID = listings[i].remoteID,
               let product = fetched.first(where: { $0.remoteID == remoteID }) {
                listings[i].remoteImageURL = product.remoteImageURL ?? listings[i].remoteImageURL
                if listings[i].syncStatus == .synced {
                    listings[i].title = product.title
                }
            }
        }

        let existingRemoteIDs = Set(listings.compactMap(\.remoteID))
        let newProducts = fetched.filter { product in
            guard let remoteID = product.remoteID else { return false }
            return !existingRemoteIDs.contains(remoteID)
        }
        listings.append(contentsOf: newProducts)
        sortListings()
    }

    private func seedOfflineItems() {
        let now = Date.now
        listings = (1...200).map { i in
            Listing(
                id: UUID(),
                remoteID: nil,
                title: "Marketplace Item #\(i)",
                isFavorite: false,
                imageFilename: nil,
                remoteImageURL: nil,
                updatedAt: now,
                syncStatus: .synced
            )
        }
        storage.save(listings)
    }
}
