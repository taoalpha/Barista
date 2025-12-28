import Foundation
import SwiftUI
import Combine

class SourceManager: ObservableObject {
    static let shared = SourceManager()
    static let favoritesSourceID = "local://favorites"
    static let manualSourceID = "local://manual"
    
    // Base URL for data. Using remote GitHub raw content.
    private let baseURL = URL(string: "https://raw.githubusercontent.com/taoalpha/Barista/refs/heads/main/data/")!
    
    @Published var favorites: [BaristaItem] = [] {
        didSet {
            saveFavorites()
            if selectedSourceID == SourceManager.favoritesSourceID {
                if favorites.isEmpty {
                    self.sourceItems = [BaristaItem(text: "No favorite item", fullText: nil, link: nil, sourceID: SourceManager.favoritesSourceID, isFavoritable: false)]
                } else {
                    self.sourceItems = favorites
                }
                self.rotateItem()
            }
        }
    }
    
    private var isPaused: Bool = false {
        didSet {
             updateTimer()
        }
    }
    
    @Published var currentItem: BaristaItem?
    @Published var isDynamicSource: Bool {
        didSet {
            UserDefaults.standard.set(isDynamicSource, forKey: "isDynamicSource")
            updateTimer()
        }
    }
    
    @Published var selectedSourceID: String? {
        didSet {
            if let id = selectedSourceID {
                UserDefaults.standard.set(id, forKey: "selectedSourceID")
                fetchContent()
            }
        }
    }
    
    @Published var itemRotationInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(itemRotationInterval, forKey: "itemRotationInterval")
            updateTimer()
        }
    }
    
    @Published var availableSources: [Source] = []
    
    private var sourceItems: [BaristaItem] = []
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.isDynamicSource = UserDefaults.standard.bool(forKey: "isDynamicSource")
        self.itemRotationInterval = UserDefaults.standard.double(forKey: "itemRotationInterval")
        if self.itemRotationInterval == 0 { self.itemRotationInterval = 60 } // Default 1 min
        
        if let idString = UserDefaults.standard.string(forKey: "selectedSourceID") {
            self.selectedSourceID = idString
        }
        
        loadFavorites()
        fetchSourcesMetadata() // Load sources.json
    }
    
    func fetchSourcesMetadata() {
        let filename = "sources.json"
        let url = baseURL.appendingPathComponent(filename)
        print("Fetching sources metadata from: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            
            var dataToUse = data
            
            // If fetch failed or no data, try cache
            if dataToUse == nil || error != nil {
                print("Error fetching sources.json: \(String(describing: error))... trying cache.")
                if let cached = self?.loadCachedData(filename: filename) {
                    print("Loaded sources.json from cache.")
                    dataToUse = cached
                } else {
                    print("No cached data for sources.json")
                    return
                }
            } else if let validData = data {
                print("Successfully fetched sources.json (\(validData.count) bytes)")
                // Success: Cache it
                self?.cacheData(validData, filename: filename)
            }
            
            guard let finalData = dataToUse else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let sources = try? JSONDecoder().decode([Source].self, from: finalData) {
                    print("Decoded \(sources.count) sources")
                    self.availableSources = sources
                    
                    // Prepend Favorites
                    let favSource = Source(
                        id: SourceManager.favoritesSourceID,
                        name: "Favorites",
                        description: "Your saved items",
                        updatedAt: 0
                    )
                     self.availableSources.insert(favSource, at: 0)
                    
                    // If no source selected, select first
                    if self.selectedSourceID == nil, let first = self.availableSources.first {
                        self.selectedSourceID = first.id
                    }
                    
                    // Initial content fetch if dynamic
                    if self.isDynamicSource {
                        self.fetchContent()
                        self.updateTimer()
                    }
                } else {
                    print("Failed to decode sources.json")
                }
            }
        }.resume()
    }
    
    func updateTimer() {
        timer?.invalidate()
        guard isDynamicSource, !isPaused else { return }
        
        // Use global setting for rotation interval
        let interval = itemRotationInterval
        
        if sourceItems.isEmpty {
           fetchContent()
        } else if currentItem == nil {
            rotateItem()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.rotateItem()
        }
    }
    private var isFetchingContent: Bool = false
    
    func fetchContent() {
        guard let source = availableSources.first(where: { $0.id == selectedSourceID }) else { return }
        
        // Concurrent fetch guard
        if isFetchingContent {
             print("Already fetching content, skipping request.")
             return
        }
        
        if source.id == SourceManager.favoritesSourceID {
            if favorites.isEmpty {
                self.sourceItems = [BaristaItem(text: "No favorite item", fullText: nil, link: nil, sourceID: SourceManager.favoritesSourceID, isFavoritable: false)]
            } else {
                self.sourceItems = favorites
            }
            self.rotateItem()
            return
        }
        
        // Check if we need to fetch based on updatedAt
        let lastFetchKey = "lastFetch_\(source.id)"
        let lastFetchTime = UserDefaults.standard.double(forKey: lastFetchKey)
        let sourceUpdatedAt = Double(source.updatedAt)
        
        // If we have a cache AND our last fetch was after the source was updated, use cache.
        // Assuming updatedAt is a unix timestamp of when the content on server changed.
        // If we fetched recently (lastFetchTime > sourceUpdatedAt), we are good.
        // Also ensure we actually have cached data.
        if lastFetchTime > sourceUpdatedAt, let cachedData = loadCachedData(filename: source.id) {
            print("Content for \(source.id) is up to date (Last fetch: \(lastFetchTime) > UpdatedAt: \(sourceUpdatedAt)). Using cache.")
            decodeAndSetItems(data: cachedData, source: source)
            return
        }
        
        isFetchingContent = true
        let url = baseURL.appendingPathComponent(source.id)
        print("Fetching content for \(source.name) from: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.isFetchingContent = false
                }
            }
            
            var dataToUse = data
            
            // If fetch failed or no data, try cache as fallback
            if dataToUse == nil || error != nil {
                print("Error fetching content \(source.id): \(String(describing: error))... trying cache fallback.")
                if let cached = self?.loadCachedData(filename: source.id) {
                     print("Loaded \(source.id) from cache (fallback).")
                    dataToUse = cached
                } else {
                    print("No cached data for \(source.id)")
                    return
                }
            } else if let validData = data {
                print("Successfully fetched content for \(source.id) (\(validData.count) bytes)")
                // Success: Cache it AND update last fetch time
                self?.cacheData(validData, filename: source.id)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
            }
            
            guard let finalData = dataToUse else { return }
            
            self?.decodeAndSetItems(data: finalData, source: source)
            
        }.resume()
    }
    
    private func decodeAndSetItems(data: Data, source: Source) {
        DispatchQueue.main.async { [weak self] in
            if let items = try? JSONDecoder().decode([BaristaItem].self, from: data) {
                print("Decoded \(items.count) items for \(source.id)")
                var itemsWithSource = items
                // Inject sourceID
                for i in 0..<itemsWithSource.count {
                    itemsWithSource[i].sourceID = source.id
                    itemsWithSource[i].isFavoritable = true // Explicitly true for fetched items
                }
                self?.sourceItems = itemsWithSource
                self?.rotateItem()
            } else {
                print("Failed to decode BaristaItems from \(source.id)")
            }
        }
    }
    
    func rotateItem() {
        let validItems = sourceItems // Assume valid
        guard !validItems.isEmpty else { return }
        let newItem = validItems.randomElement()
        currentItem = newItem
        
        // Update main app storage so the menu bar updates automatically
        DispatchQueue.main.async {
            if let text = newItem?.text {
                UserDefaults.standard.set(text, forKey: "baristaText")
            }
        }
    }
    
    func forceRefresh() {
        rotateItem()
    }
    
    func pauseTimer() { 
        isPaused = true 
    }
    
    func resumeTimer() { 
        isPaused = false 
    }
    
    func toggleFavorite(_ item: BaristaItem) {
        if favorites.contains(item) {
             favorites.removeAll(where: { $0 == item })
        } else {
             favorites.append(item)
        }
    }
    
    // Legacy support helper
    func toggleFavorite(text: String) {
        // Create full item from currently displayed text if possible, or new item
        if let current = currentItem, current.text == text {
            toggleFavorite(current)
        } else {
            // Fallback: create item with just this text
            let newItem = BaristaItem(text: text)
            toggleFavorite(newItem)
        }
    }
    
    private func loadFavorites() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("barista_favorites.json")
        if let data = try? Data(contentsOf: url) {
            if let loaded = try? JSONDecoder().decode([BaristaItem].self, from: data) {
                self.favorites = loaded
            } else if let strings = try? JSONDecoder().decode([String].self, from: data) {
                // Migrate legacy strings
                self.favorites = strings.map { BaristaItem(text: $0) }
            }
        }
    }
    
    private func saveFavorites() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("barista_favorites.json")
        if let data = try? JSONEncoder().encode(favorites) {
            try? data.write(to: url)
        }
    }
    
    // MARK: - Caching Helpers
    
    private var cacheDirectory: URL? {
        // Use Caches directory
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheDir = paths.first?.appendingPathComponent("BaristaJSONCache") else { return nil }
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        }
        return cacheDir
    }
    
    private func cacheData(_ data: Data, filename: String) {
        guard let cacheDir = cacheDirectory else { return }
        // Sanitize filename if needed (e.g. replace slashes) - but our incoming filenames are usually simple.
        // If filename is a URL or has path components, take last component or hash it?
        // Let's assume filename is "quotes.json" or "local://favorites" (handled separately).
        // Remote filenames might just be "quotes.json".
        
        // If filename contains invalid chars, we might fail. Let's just use the last path component if it looks like a path.
        let safeName = URL(fileURLWithPath: filename).lastPathComponent
        let fileURL = cacheDir.appendingPathComponent(safeName)
        
        try? data.write(to: fileURL)
    }
    
    private func loadCachedData(filename: String) -> Data? {
        guard let cacheDir = cacheDirectory else { return nil }
        let safeName = URL(fileURLWithPath: filename).lastPathComponent
        let fileURL = cacheDir.appendingPathComponent(safeName)
        return try? Data(contentsOf: fileURL)
    }
}
