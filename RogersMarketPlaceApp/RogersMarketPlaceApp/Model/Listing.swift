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
    var remoteID: Int?
    var title: String
    var isFavorite: Bool
    var imageFilename: String?
    var remoteImageURL: String?
    var updatedAt: Date
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        remoteID: Int? = nil,
        title: String,
        isFavorite: Bool = false,
        imageFilename: String? = nil,
        remoteImageURL: String? = nil,
        updatedAt: Date = .now,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.remoteID = remoteID
        self.title = title
        self.isFavorite = isFavorite
        self.imageFilename = imageFilename
        self.remoteImageURL = remoteImageURL
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
}
