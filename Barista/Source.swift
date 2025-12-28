import Foundation

struct BaristaItem: Codable, Hashable {
    let text: String
    let fullText: String?
    let link: String?
    var sourceID: String? = nil
    var isFavoritable: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case text, fullText, link, sourceID, isFavoritable
    }
    
    init(text: String, fullText: String? = nil, link: String? = nil, sourceID: String? = nil, isFavoritable: Bool = true) {
        self.text = text
        self.fullText = fullText
        self.link = link
        self.sourceID = sourceID
        self.isFavoritable = isFavoritable
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(String.self, forKey: .text)
        self.fullText = try container.decodeIfPresent(String.self, forKey: .fullText)
        self.link = try container.decodeIfPresent(String.self, forKey: .link)
        self.sourceID = try container.decodeIfPresent(String.self, forKey: .sourceID)
        self.isFavoritable = try container.decodeIfPresent(Bool.self, forKey: .isFavoritable) ?? true
    }
}

struct Source: Identifiable, Codable, Hashable {
    var id: String
    let name: String
    let description: String
    let refreshInterval: TimeInterval
    
    private enum CodingKeys: String, CodingKey {
        case name, description, refreshInterval, filename
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.refreshInterval = try container.decode(TimeInterval.self, forKey: .refreshInterval)
        // Decode filename directly into id
        self.id = try container.decode(String.self, forKey: .filename)
    }
    
    // Initializer for manual creation (e.g. Favorites, or manual)
    init(id: String = SourceManager.manualSourceID, name: String, description: String, refreshInterval: TimeInterval) {
        self.id = id
        self.name = name
        self.description = description
        self.refreshInterval = refreshInterval
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(refreshInterval, forKey: .refreshInterval)
        // Encode id back to filename key
        try container.encode(id, forKey: .filename)
    }
}
