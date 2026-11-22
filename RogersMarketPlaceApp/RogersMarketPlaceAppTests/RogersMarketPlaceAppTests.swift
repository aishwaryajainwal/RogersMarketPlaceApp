//
//  RogersMarketPlaceAppTests.swift
//  RogersMarketPlaceAppTests
//
//  Created by TINA JAINWAL on 21/11/26.
//

import Combine
import XCTest
@testable import RogersMarketPlaceApp


// MARK: - Mock

final class MemoryStorage: ListingStorageProtocol {
    var items: [Listing] = []
    func load() -> [Listing] { items }
    func save(_ items: [Listing]) { self.items = items }
}

final class TestNetwork: NetworkMonitoring {
    func isNetworkAvailable() async -> Bool {
        return false
    }
    
    let isOnline: CurrentValueSubject<Bool, Never>
    init(_ online: Bool) {
        self.isOnline = CurrentValueSubject<Bool, Never>(online)
    }
}

actor TestAPI: MarketplaceAPIProtocol {
    func fetchListings(limit: Int) async throws -> [RogersMarketPlaceApp.Listing] {
        return []
    }
    
    func upsertListing(_ item: RogersMarketPlaceApp.Listing) async throws -> RogersMarketPlaceApp.Listing {
        return await Listing(title: "")
    }
    
    func sync(items: [Listing]) async throws -> [Listing] {
        await MainActor.run {
            items.map { item in
                var copy = item
                copy.syncStatus = .synced
                return copy
            }
        }
    }
}

@MainActor
final class RogersMarketPlaceAppTests: XCTestCase {
    private var vm: MarketplaceVM?
    private var storage: MemoryStorage?
    private var network: TestNetwork?
    
    override func tearDown() {
        vm = nil
        network = nil
        storage = nil
        super.tearDown()
    }
    
    func testAddListingOfflineIsPending() {
        let memStorage = MemoryStorage()
        memStorage.items = [
            Listing(
                id: UUID(),
                title: "Seed",
                isFavorite: false,
                imageFilename: nil,
                updatedAt: .now,
                syncStatus: .synced
            )
        ]
        let net = TestNetwork(false)
        let viewModel = MarketplaceVM(
            storage: memStorage,
            marketplaceAPIProtocol: TestAPI(),
            networkMonitoring: net
        )
        
        self.storage = memStorage
        self.network = net
        self.vm = viewModel
        
        viewModel.addListing(title: "Photo Album", image: nil)
        
        XCTAssertEqual(viewModel.listings.first?.title, "Photo Album")
        XCTAssertEqual(viewModel.listings.first?.syncStatus, .pending)
    }
    
    func testToggleFavoriteMarksPending() {
        let memStorage = MemoryStorage()
        let item = Listing(
            id: UUID(),
            title: "Chair",
            isFavorite: false,
            imageFilename: nil,
            updatedAt: .distantPast,
            syncStatus: .synced
        )
        memStorage.items = [item]
        
        let net = TestNetwork(false)
        let viewModel = MarketplaceVM(
            storage: memStorage,
            marketplaceAPIProtocol: TestAPI(),
            networkMonitoring: net
        )
        
        self.storage = memStorage
        self.network = net
        self.vm = viewModel
        
        viewModel.toggleFavorite(item)
        
        XCTAssertEqual(viewModel.listings.first?.isFavorite, true)
        XCTAssertEqual(viewModel.listings.first?.syncStatus, .pending)
        XCTAssertEqual(memStorage.items.first?.isFavorite, true)
    }
    
    // 2. Search filters listings by title
    func testSearchFiltersListings() {
        let memStorage = MemoryStorage()
        memStorage.items = [
            Listing(
                id: UUID(),
                title: "iPhone 16",
                isFavorite: false,
                imageFilename: nil,
                updatedAt: .now,
                syncStatus: .synced
            ),
            Listing(
                id: UUID(),
                title: "Wooden Desk",
                isFavorite: false,
                imageFilename: nil,
                updatedAt: .now,
                syncStatus: .synced
            )
        ]

        let net = TestNetwork(true)
        let viewModel = MarketplaceVM(
            storage: memStorage,
            marketplaceAPIProtocol: TestAPI(),
            networkMonitoring: net
        )

        self.storage = memStorage
        self.network = net
        self.vm = viewModel

        viewModel.searchText = "phone"

        XCTAssertEqual(viewModel.filteredListings.count, 1)
        XCTAssertEqual(viewModel.filteredListings.first?.title, "iPhone 16")
    }
}


