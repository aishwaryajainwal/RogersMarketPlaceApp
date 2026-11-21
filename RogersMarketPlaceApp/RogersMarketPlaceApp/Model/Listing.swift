//
//  Listing.swift
//  RogersMarketPlaceApp
//
//  Created by TINA JAINWAL on 19/11/26.
//

import Foundation

enum SyncStatus: String, Codable {
    case synced
    case pending
}

struct Listing: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isFavorite: Bool
    var imageFilename: String?
    var updatedAt: Date
    var syncStatus: SyncStatus
}
