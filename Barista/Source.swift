import Foundation

struct Source: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var url: URL
    
    init(id: UUID = UUID(), name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }
}

// A simple structure for the manifest of sources
struct SourceManifest: Codable {
    let sources: [Source]
}
