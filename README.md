# RogersMarketPlaceApp


## Performance Benchmarks & Resource Considerations (200 Listings)

### Measured CPU & Memory Profile (Xcode Debug Navigator)
Tested with **200 seeded listings** under rapid scrolling, live search filtering, and offline favorite toggling:

| App State | CPU Usage | Behavior & Explanation |
| :--- | :--- | :--- |
| **Cold Launch (Initial Seed)** | ~105% (brief burst < 0.3s) | One-time initialization of SwiftUI hierarchy, JSON seeding (`200` records), and initial `List` layout pass across cores. |
| **Idle (Feed Displayed)** | **0%** | Zero background polling; Combine `NWPathMonitor` and `List` remain completely dormant until user input or network state change occurs. |
| **Active Scrolling & Search** | **2% – 24%** (avg ~8%) | Lightweight main-thread

### Measured CPU & Memory Profile (Xcode Debug Navigator)
Tested with **200 seeded listings** under rapid scrolling, live search filtering, and offline favorite toggling:

| App State | CPU Usage | Memory Usage | Behavior & Explanation |
| :--- | :--- | :--- | :--- |
| **Cold Launch (Initial Seed)** | ~105% (brief burst < 0.3s) | **~48.5 MB** | One-time initialization of SwiftUI hierarchy, JSON seeding (`200` records), and initial `List` layout pass across cores. |
| **Idle (Feed Displayed)** | **0%** | **~48.5 MB** | Zero background polling; Combine `NWPathMonitor` and `List` remain completely dormant until user input or network state change occurs. |
| **Active Scrolling & Search** | **2% – 24%** (avg ~8%) | **Up to ~68 MB** (~19.5 MB delta) | Lightweight main-thread diffing for visible cells, in-memory search filtering, and cached `300x300` thumbnails as rows are scrolled. |

---

### Memory Considerations
- **Tight Footprint (~48.5 MB – 68 MB):** Even with 200 listings and active scrolling, peak memory stays around **68 MB**—well below iOS memory limits for background/foreground apps.
- **Bounded Growth via `NSCache` & Thumbnailing:** Images are downsampled to `300x300` JPEGs on save (`ImageStore.saveImage`) and capped at `100` items in `NSCache`, preventing unbounded memory growth as more listings or photos are added.


### System Architecture Diagram
flowchart TB
    subgraph UI["SwiftUI View Layer (@MainActor)"]
        CV["ContentView<br/>(List, Search, Sync Banner)"]
        ALS["AddListingScreen<br/>(Title, PhotoPicker / Camera)"]
        IP["ImagePicker<br/>(UIImagePickerController)"]
    end

    subgraph VM["ViewModel Layer (@MainActor)"]
        MVM["MarketplaceVM : ObservableObject<br/>• listings: [Listing]<br/>• searchText: String<br/>• isOnline: Bool<br/>• addListing(), toggleFavorite()<br/>• syncNow(), mergeRemote()"]
    end

    subgraph Protocols["Dependency Injection Protocols"]
        SP["ListingStorageProtocol"]
        AP["MarketplaceAPIProtocol"]
        NP["NetworkMonitoring"]
    end

    subgraph Infra["Concrete Services & Persistence"]
        LS["LocalStorage<br/>Documents/listings.json"]
        IS["ImageStore (Singleton)<br/>NSCache (100) + Caches/*.jpg"]
        NM["NetworkMonitor<br/>NWPathMonitor → CurrentValueSubject"]
        API["MockAPIService (actor)<br/>serverDB + Last-Write-Wins"]
    end

    CV -->|"observes @Published / calls intents"| MVM
    ALS -->|"calls addListing()"| MVM
    ALS -->|"presents"| IP

    MVM -.->|"depends on"| SP
    MVM -.->|"depends on"| AP
    MVM -.->|"depends on"| NP

    LS -.->|"conforms"| SP
    API -.->|"conforms"| AP
    NM -.->|"conforms"| NP

    MVM -->|"saveImage / loadImage"| IS


### Sequence Diagram — Offline Creation & Auto-Sync on Reconnect
sequenceDiagram
    autonumber
    actor User
    participant View as AddListingScreen / ContentView
    participant VM as MarketplaceVM (@MainActor)
    participant Img as ImageStore
    participant Storage as LocalStorage
    participant Net as NetworkMonitor
    participant API as MockAPIService (actor)

    Note over User,API: Phase 1 — Offline Listing Creation
    User->>View: Enter title, pick/capture photo, tap Save
    View->>VM: addListing(title:image:)
    opt Image Provided
        VM->>Img: saveImage(uiImage)
        Img-->>VM: filename.jpg (300x300 JPEG cached + disk)
    end
    VM->>VM: Insert Listing(syncStatus: .pending, updatedAt: .now)
    VM->>Storage: save(listings) -> listings.json
    Note over VM: isOnline == false -> skips immediate syncNow()
    VM-->>View: @Published listings updates UI

    Note over User,API: Phase 2 — Connectivity Restored & Auto-Sync
    Net-->>VM: isOnline.send(true) via Combine sink
    VM->>VM: Update isOnline = true; spawn Task { await syncNow() }
    VM->>API: sync(items: pendingItems)
    activate API
    API->>API: Simulate 400ms latency & apply Last-Write-Wins
    API-->>VM: Return server items (syncStatus = .synced)
    deactivate API
    VM->>VM: mergeRemote(remoteItems) (Last-Write-Wins)
    VM->>Storage: save(listings) -> listings.json
    VM-->>View: @Published listings refreshes UI (synced state)
