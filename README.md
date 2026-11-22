Markdown

# 🛍️ RogersMarketPlaceApp

An **offline-first marketplace iOS application** built with **SwiftUI**, **Combine**, **Swift Concurrency**, and **MVVM** architecture.

The application allows users to browse marketplace listings, search items, add new listings locally using the photo library or camera, toggle favorites, persist data locally to JSON, and synchronize pending changes when network connectivity is available.

## ✨ Features

- 📦 Product listing feed with pull-to-refresh (`refreshable`) and live search (`searchable`)
- ➕ Add new listings locally (requires at least 2 non-whitespace characters in the title)
- ❤️ Favorite / unfavorite listings with automatic sorting (favorites first, then most recently updated)
- 💾 Local JSON persistence via `LocalStorage` in the Documents directory (`listings.json`)
- 🔄 Offline queuing and automatic/manual synchronization of `.pending` items with `DummyJSONAPIService`
- 🌐 Real-time network reachability monitoring via `NetworkMonitor` (`NWPathMonitor` + periodic Apple connectivity probe)
- 📴 Offline seeding of 200 fallback listings (`Marketplace Item #1`–`#200`) when starting offline with no saved listings
- 🖼️ Photo selection via `PhotosPicker` and camera capture via `CameraPicker` (`NSCameraUsageDescription` configured in `Info.plist`)
- ⚡ Two-tier thumbnail caching (`NSCache` in-memory + `Caches` directory on disk, resized to `300x300` JPEG at `0.7` quality) via `ImageStore`

## 🛠 Tech Stack

| Technology | Usage |
| :--- | :--- |
| **Swift** | Primary programming language |
| **SwiftUI** | User interface (`ContentView`, `AddListingScreen`, `CameraPicker`) |
| **Combine** | Reactive connectivity updates (`CurrentValueSubject`) and `ObservableObject` state |
| **Swift Concurrency** | `async`/`await`, `Task`, and `AsyncStream` for network calls, image loading, and monitoring |
| **Network (`NWPathMonitor`)** | Path change notifications combined with `URLSession` connectivity checks |
| **PhotosUI & UIKit** | `PhotosPicker` and `UIImagePickerController` camera wrapper |
| **NSCache & FileManager** | In-memory and disk thumbnail caching plus JSON file persistence |

## 📂 Project Structure

- `Listing.swift` — `Listing` model (`Identifiable`, `Codable`, `Equatable`) and `SyncStatus` enum (`.synced`, `.pending`)
- `AppServices.swift` — `ListingStorageProtocol`, `LocalStorage` (`listings.json`), and `ImageStore` (memory & disk thumbnail cache)
- `NetworkService.swift` — `APIError`, `MarketplaceAPIProtocol`, `NetworkMonitoring`, `NetworkMonitor`, and `DummyJSONAPIService` (`https://dummyjson.com`)
- `MarketplaceVM.swift` — `@MainActor` `MarketplaceVM` handling local CRUD/favorites, search filtering, offline seeding, and remote sync/merge logic
- `ContentView.swift` — Main marketplace screen with connectivity banner, searchable list, pull-to-refresh, favorite toggles, and `RemoteThumbnailView`
- `AddListingScreen.swift` — Sheet form for creating a listing with title validation, `PhotosPicker`, and camera access
- `CameraPicker.swift` — `UIViewControllerRepresentable` wrapper around `UIImagePickerController` (`.camera`)

## 🏗️ Architecture

The app follows **MVVM** with protocol-oriented service dependencies injected into `MarketplaceVM`:

```text
SwiftUI Views (ContentView, AddListingScreen, CameraPicker)
       │
       ▼
MarketplaceVM (@MainActor, ObservableObject)
   ├── ListingStorageProtocol ──▶ LocalStorage (Documents/listings.json)
   ├── MarketplaceAPIProtocol ──▶ DummyJSONAPIService ([https://dummyjson.com](https://dummyjson.com))
   ├── NetworkMonitoring      ──▶ NetworkMonitor (NWPathMonitor + HEAD probe)
   └── ImageStore.shared      ──▶ NSCache + Caches directory (300x300 thumbnails)

## ⚡ Performance (200 Listings)

Tested with **200 listings** (including offline fallback seeding of `Marketplace Item #1`–`#200` and remote/cached thumbnails) while monitoring CPU and memory usage in Xcode:

- **CPU Behavior:** Spiked initially to **~85%** on launch/sync/image decoding, briefly dropped to **0%** when idle, and fluctuated between **37%–97%** (e.g., `94%`, `95%`, `40%`, `59%`, `47%`, `37%`, `97%`) during active scrolling, remote thumbnail fetching, and thumbnail decoding.
- **Memory Footprint:** Started at **~30.6 MB** on launch and scaled gradually up to **~72 MB** (`37.8 MB` → `41.7 MB` → `46.7 MB` → `53.6 MB` → `69 MB` → `71 MB` → `72 MB`) as thumbnails were loaded, downsampled, and cached across scrolling.

### Memory & CPU Considerations in Code

- **Thumbnail Downsampling (`ImageStore`):** Full-resolution images from `PhotosPicker`, `CameraPicker`, or network responses are downsampled to `300x300` (`preparingThumbnail(of:)`) and compressed as JPEG (`0.7` quality) before caching or writing to disk, preventing large raw bitmaps from inflating memory.
- **Bounded In-Memory Cache + Disk Cache (`ImageStore`):** Uses `NSCache` (capped at `100` items) so iOS can evict cached images under memory pressure, paired with disk caching in `Caches` so thumbnails don't need to be re-downloaded repeatedly.
- **Atomic & Pre-Sized Collection Operations:** `LocalStorage.save(_:)` writes `listings.json` atomically via `Data.write(to:options: .atomic)`, and `DummyJSONAPIService.sync(items:)` uses `reserveCapacity(items.count)` to avoid repeated array reallocations.
- **Asynchronous Network & Image Work:** Remote product fetches, sync calls, and remote thumbnail downloads run asynchronously (`async`/`await` and view `.task(id:)`) rather than blocking the main thread.
