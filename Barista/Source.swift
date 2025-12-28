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
    let id: String
    let name: String
    let description: String
    let updatedAt: Int
    
    // Manual creation
    init(id: String = "local://manual", name: String, description: String, updatedAt: Int = 0) {
        self.id = id
        self.name = name
        self.description = description
        self.updatedAt = updatedAt
    }
    
    // Custom decoding to map filename -> id
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Use filename as ID just like before
        self.id = try container.decode(String.self, forKey: .filename)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.updatedAt = try container.decodeIfPresent(Int.self, forKey: .updatedAt) ?? 0
    }
    
    // Custom encoding to map id -> filename
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(updatedAt, forKey: .updatedAt)
        
        // Encode ID back to "filename" for consistent JSON structure
        try container.encode(id, forKey: .filename)
    }
    
    enum CodingKeys: String, CodingKey {
        case name, description, updatedAt, filename
    }
}
