//
//  AppServices.swift
//  RogersMarketPlaceApp
//
//  Created by TINA JAINWAL on 19/11/26.
//

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
              let items = try? JSONDecoder().decode([Listing].self, from: data) else {
            return []
        }
        return items
    }

    func save(_ items: [Listing]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class ImageStore {
    static let shared = ImageStore()

    private let cache = NSCache<NSString, UIImage>()
    private let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    private let thumbnailSize = CGSize(width: 300, height: 300)

    init() {
        cache.countLimit = 100
    }

    func saveImage(_ image: UIImage) -> String? {
        let thumbnail = makeThumbnail(from: image)
        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        try? data.write(to: folder.appendingPathComponent(filename))
        cache.setObject(thumbnail, forKey: filename as NSString)
        return filename
    }

    func loadImage(_ filename: String?) -> UIImage? {
        guard let filename else { return nil }
        if let cached = cache.object(forKey: filename as NSString) {
            return cached
        }
        let filePath = folder.appendingPathComponent(filename).path
        guard let image = UIImage(contentsOfFile: filePath) else { return nil }
        cache.setObject(image, forKey: filename as NSString)
        return image
    }

    func loadRemoteThumbnail(urlString: String?, cacheKey: String) async -> UIImage? {
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }
        if let diskCached = loadImage(cacheKey) {
            return diskCached
        }
        guard let urlString, let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let original = UIImage(data: data) else { return nil }
            let thumbnail = makeThumbnail(from: original)
            if let jpegData = thumbnail.jpegData(compressionQuality: 0.7) {
                try? jpegData.write(to: folder.appendingPathComponent(cacheKey))
            }
            cache.setObject(thumbnail, forKey: cacheKey as NSString)
            return thumbnail
        } catch {
            return nil
        }
    }

    private func makeThumbnail(from image: UIImage) -> UIImage {
        image.preparingThumbnail(of: thumbnailSize) ?? image
    }
}
