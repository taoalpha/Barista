import Foundation
import SwiftUI
import Combine

class SourceManager: ObservableObject {
    static let shared = SourceManager()
    static let favoritesSourceID = UUID(uuidString: "FA708173-FA70-FA70-FA70-FA708173FA70")!
    
    @Published var favorites: [String] = [] {
        didSet {
            saveFavorites()
            updateAvailableSources()
            if selectedSourceID == SourceManager.favoritesSourceID {
                self.sourceItems = favorites
                if favorites.isEmpty && isDynamicSource {
                    isDynamicSource = false
                }
            }
        }
    }
    
    private var isPaused: Bool = false {
        didSet {
             updateTimer()
        }
    }
    
    @Published var currentText: String?
    @Published var isDynamicSource: Bool {
        didSet {
            UserDefaults.standard.set(isDynamicSource, forKey: "isDynamicSource")
            updateTimer()
        }
    }
    
    @Published var selectedSourceID: UUID? {
        didSet {
            if let id = selectedSourceID {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedSourceID")
                fetchContent()
            }
        }
    }
    
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            updateTimer()
        }
    }
    
    @Published var availableSources: [Source] = []
    
    private var sourceItems: [String] = []
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.isDynamicSource = UserDefaults.standard.bool(forKey: "isDynamicSource")
        self.refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        if self.refreshInterval == 0 { self.refreshInterval = 60 } // Default 1 min
        
        if let idString = UserDefaults.standard.string(forKey: "selectedSourceID"),
           let id = UUID(uuidString: idString) {
            self.selectedSourceID = id
        }
        
        // Load default sources (Mock for now, or fetch from GitHub)
        loadFavorites()
        updateAvailableSources()
        
        if isDynamicSource {
            fetchContent()
            updateTimer()
        }
    }
    
    func updateTimer() {
        timer?.invalidate()
        guard isDynamicSource, !isPaused else { return }
        
        // Fire immediately to ensure content
        if sourceItems.isEmpty {
           fetchContent()
        } else if currentText == nil || currentText?.isEmpty == true {
            rotateText()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.rotateText()
        }
    }
    
    func fetchContent() {
        guard let source = availableSources.first(where: { $0.id == selectedSourceID }) else { return }
        
        if source.id == SourceManager.favoritesSourceID {
            self.sourceItems = favorites
            self.rotateText()
            return
        }
        
        URLSession.shared.dataTask(with: source.url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching source: \(String(describing: error))")
                return
            }
            
            // Simple string array parsing for now. 
            // NOTE: The user mentioned complex JSONs. We might need specific parsing logic per source or a generic one.
            // For this clone, let's assume a standard format or try to parse generic arrays.
            // Given the user said "format of json file", let's assume a list of strings [ "str1", "str2" ]
            // OR a specific format. I will try to decode [String] first.
            
            DispatchQueue.main.async {
                if let strings = try? JSONDecoder().decode([String].self, from: data) {
                    self?.sourceItems = strings
                    self?.rotateText()
                } else if let complex = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                     // Try to extract "quote" and "author"
                     self?.sourceItems = complex.compactMap { dict in
                         if let quote = dict["quote"] as? String, let author = dict["author"] as? String { return "\(quote) - \(author)" }
                         return nil
                     }
                    self?.rotateText()
                }
            }
        }.resume()
    }
    
    func rotateText() {
        let validItems = sourceItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !validItems.isEmpty else { return }
        let newText = validItems.randomElement() ?? ""
        currentText = newText
        
        // Update main app storage so the menu bar updates automatically
        DispatchQueue.main.async {
            UserDefaults.standard.set(newText, forKey: "baristaText")
        }
    }
    
    func forceRefresh() {
        rotateText()
    }
    
    func pauseTimer() { 
        isPaused = true 
    }
    
    func resumeTimer() { 
        isPaused = false 
    }
    
    func toggleFavorite(_ text: String) {
        if favorites.contains(text) {
             favorites.removeAll(where: { $0 == text })
        } else {
             favorites.append(text)
        }
    }
    
    private func loadFavorites() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("barista_favorites.json")
        if let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode([String].self, from: data) {
            self.favorites = loaded
        }
    }
    
    private func saveFavorites() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("barista_favorites.json")
        if let data = try? JSONEncoder().encode(favorites) {
            try? data.write(to: url)
        }
    }
    
    private func updateAvailableSources() {
        var sources = [
             Source(
                id: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!, 
                name: "Inspirational Quotes", 
                url: URL(string: "https://raw.githubusercontent.com/AtaGowani/daily-motivation/refs/heads/master/src/data/quotes.json")!
            )
        ]
        
        if !favorites.isEmpty {
            sources.insert(Source(id: SourceManager.favoritesSourceID, name: "Favorites", url: URL(string: "local://favorites")!), at: 0)
        }
        
        self.availableSources = sources
    }
}
