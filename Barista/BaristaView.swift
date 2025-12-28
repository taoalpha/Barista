import SwiftUI

struct BaristaView: View {
    @AppStorage("baristaText") private var text: String = ""
    @StateObject private var sourceManager = SourceManager.shared

    var body: some View {
        VStack(spacing: 16) {
            if sourceManager.isDynamicSource {
                VStack(spacing: 8) {
                    if let item = sourceManager.currentItem {
                        VStack(spacing: 4) {
                            Text(item.text)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if let fullText = item.fullText {
                                Text(fullText)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            if let linkString = item.link, let url = URL(string: linkString) {
                                Link("Read More", destination: url)
                                    .font(.caption)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    
                    Divider()
                    
                    // Footer: Source Info & Controls
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Source: \(sourceManager.availableSources.first(where: { $0.id == sourceManager.selectedSourceID })?.name ?? "Unknown")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Button("Switch to Manual") {
                                sourceManager.isDynamicSource = false
                            }
                            .buttonStyle(.link)
                            .controlSize(.mini)
                        }
                        
                        Spacer()
                        
                        if let item = sourceManager.currentItem, item.isFavoritable {
                            Button(action: {
                                sourceManager.toggleFavorite(item)
                            }) {
                                let isFavorited = sourceManager.favorites.contains(item)
                                Image(systemName: isFavorited ? "heart.fill" : "heart")
                                    .foregroundColor(isFavorited ? .red : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Toggle Favorite")
                            .padding(.trailing, 4)
                        }
                        
                        Button("Next") {
                            sourceManager.forceRefresh()
                        }
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    TextField("Type here...", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 220) // Slightly wider
                    
                    if let selectedID = sourceManager.selectedSourceID,
                       let sourceName = sourceManager.availableSources.first(where: { $0.id == selectedID })?.name {
                        Button("Switch back to \(sourceName)") {
                            sourceManager.isDynamicSource = true
                            sourceManager.updateTimer()
                        }
                        .buttonStyle(.link)
                        .controlSize(.mini)
                    }
                }
            }

            HStack {
                Button("Settings") {
                    SettingsManager.shared.showSettings()
                }
                .controlSize(.small)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .controlSize(.small)
            }
        }
        .padding()
        .background(.ultraThinMaterial) // More translucent
        .cornerRadius(12)
    }
}
