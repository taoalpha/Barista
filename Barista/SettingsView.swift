import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @StateObject private var sourceManager = SourceManager.shared
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update launch at login: \(error)")
                        }
                    }
            } header: {
                Text("General")
            }
            
            Section {
                Toggle("Enable Sources", isOn: $sourceManager.isDynamicSource)
                
                if sourceManager.isDynamicSource {
                    Picker("Source", selection: $sourceManager.selectedSourceID) {
                        Text("Select a Source").tag(nil as String?)
                        ForEach(sourceManager.availableSources) { source in
                            Text(source.name).tag(source.id as String?)
                        }
                    }
                    
                    Picker("Rotate Item Every", selection: $sourceManager.itemRotationInterval) {
                        Text("1 Minute").tag(60.0)
                        Text("5 Minutes").tag(300.0)
                        Text("15 Minutes").tag(900.0)
                        Text("1 Hour").tag(3600.0)
                        Text("24 Hours").tag(86400.0)
                    }
                }
            } header: {
                Text("Content Source")
            }
            

        }
        .formStyle(.grouped)
        // Removed fixed frame to allow dynamic sizing
        .navigationTitle("Settings")
    }
}
