import SwiftUI
import SwiftData

@main
struct FreePassApp: App {
    @State private var appState = AppState()
    private let container: ModelContainer

    init() {
        do {
            let schema = Schema([VaultItem.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(container)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .defaultAppStorage(UserDefaults.standard)

        // Menu bar extra
        MenuBarExtra("FreePass", systemImage: "lock.shield.fill", isInserted: Bindable(appState).showMenuBarIcon) {
            MenuBarPopoverView()
                .environment(appState)
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
                .modelContainer(container)
        }
        #endif
    }
}
