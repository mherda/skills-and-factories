import SwiftUI

struct ContentView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "{{DISPLAY_NAME}}",
                systemImage: "sparkles",
                description: Text("Nothing here yet.")
            )
            .navigationTitle("{{DISPLAY_NAME}}")
            .toolbar {
                Button("Settings", systemImage: "gearshape") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear(perform: openFactoryScreen)
    }

    /// Opens the screen named by `-factoryScreen` (debug builds only). Add a
    /// case for every screen worth a screenshot, and list it in CLAUDE.md
    /// (Screens) and factory/config.sh (SCREENS).
    private func openFactoryScreen() {
        switch FactoryLaunch.screen {
        case "settings": showSettings = true
        default: break
        }
    }
}

#Preview {
    ContentView()
}
