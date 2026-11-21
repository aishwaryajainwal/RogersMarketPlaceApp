//
//  AppServices.swift
//  RogersMarketPlaceApp
//
//  Created by TINA JAINWAL on 19/11/26.
//

import Combine
import Network
import Security
import UIKit

protocol ListingStorageProtocol {
    func load() -> [Listing]
    func save(_ items: [Listing])
}

final class LocalStorage: ListingStorageProtocol {
    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("listings.json")

    func load() -> [Listing] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([Listing].self, from: data) else { return [] }
        return items
    }

    func save(_ items: [Listing]) {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

final class ImageStore {
    static let shared = ImageStore()
    private let cache = NSCache<NSString, UIImage>()
    private let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]

    init() { cache.countLimit = 100 }

    func saveImage(_ image: UIImage) -> String? {
        let thumbnail = image.preparingThumbnail(of: CGSize(width: 300, height: 300)) ?? image
        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        try? data.write(to: folder.appendingPathComponent(filename))
        cache.setObject(thumbnail, forKey: filename as NSString)
        return filename
    }

    func loadImage(_ filename: String?) -> UIImage? {
        guard let filename else { return nil }
        if let cached = cache.object(forKey: filename as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: folder.appendingPathComponent(filename).path) else { return nil }
        cache.setObject(image, forKey: filename as NSString)
        return image
    }
}
