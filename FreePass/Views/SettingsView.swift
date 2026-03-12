import SwiftUI
import SafariServices
import ServiceManagement
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    // We bind local state to AppState's properties for simplicity.
    @State private var lockTimeout: TimeInterval = 300
    @State private var clearClipboardDelay: TimeInterval = 30
    @State private var lockOnSleep: Bool = true
    @State private var touchIDEnabled: Bool = false
    
    @State private var showMenuBarIcon: Bool = true
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    
    // Additional settings state
    @State private var extensionEnabled: Bool = UserDefaults.standard.object(forKey: "extensionEnabled") != nil ? UserDefaults.standard.bool(forKey: "extensionEnabled") : true
    
    @State private var defaultPasswordLength: Double = UserDefaults.standard.object(forKey: "defaultPasswordLength") != nil ? UserDefaults.standard.double(forKey: "defaultPasswordLength") : 20.0
    @State private var defaultPasswordUppercase: Bool = UserDefaults.standard.object(forKey: "defaultPasswordUppercase") != nil ? UserDefaults.standard.bool(forKey: "defaultPasswordUppercase") : true
    @State private var defaultPasswordLowercase: Bool = UserDefaults.standard.object(forKey: "defaultPasswordLowercase") != nil ? UserDefaults.standard.bool(forKey: "defaultPasswordLowercase") : true
    @State private var defaultPasswordDigits: Bool = UserDefaults.standard.object(forKey: "defaultPasswordDigits") != nil ? UserDefaults.standard.bool(forKey: "defaultPasswordDigits") : true
    @State private var defaultPasswordSymbols: Bool = UserDefaults.standard.object(forKey: "defaultPasswordSymbols") != nil ? UserDefaults.standard.bool(forKey: "defaultPasswordSymbols") : true
    
    @State private var activeAlert: SettingsAlert?

    var body: some View {
        ZStack {
            // Root glass layer that bleeds into the title bar
            Color.clear.liquidGlass(material: .hudWindow)
                .ignoresSafeArea()
            
            NavigationStack {
                Form {
                    Section(header: Text("Security")) {
                        Picker("Auto-Lock", selection: $lockTimeout) {
                            Text("1 Minute").tag(TimeInterval(60))
                            Text("5 Minutes").tag(TimeInterval(300))
                            Text("10 Minutes").tag(TimeInterval(600))
                            Text("30 Minutes").tag(TimeInterval(1800))
                            Text("1 Hour").tag(TimeInterval(3600))
                            Text("Never").tag(TimeInterval(0))
                        }
                        .onChange(of: lockTimeout) { _, newValue in
                            appState.lockTimeout = newValue
                        }

                        Picker("Clear Clipboard", selection: $clearClipboardDelay) {
                            Text("10 Seconds").tag(TimeInterval(10))
                            Text("30 Seconds").tag(TimeInterval(30))
                            Text("1 Minute").tag(TimeInterval(60))
                            Text("2 Minutes").tag(TimeInterval(120))
                            Text("Never").tag(TimeInterval(0))
                        }
                        .onChange(of: clearClipboardDelay) { _, newValue in
                            appState.clearClipboardDelay = newValue
                        }

                        Toggle("Lock Vault on Sleep", isOn: $lockOnSleep)
                            .onChange(of: lockOnSleep) { _, newValue in
                                appState.lockOnSleep = newValue
                            }

                        if AppState().touchIDEnabled { // Just checking if it's already enabled, but wait, BiometricAuth could be checked
                            Toggle("Enable Touch ID", isOn: $touchIDEnabled)
                                .onChange(of: touchIDEnabled) { _, newValue in
                                    appState.touchIDEnabled = newValue
                                }
                        } else {
                            Toggle("Enable Touch ID", isOn: $touchIDEnabled)
                                .onChange(of: touchIDEnabled) { _, newValue in
                                    appState.touchIDEnabled = newValue
                                }
                        }
                    }

                    Section(header: Text("General")) {
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, newValue in
                                do {
                                    if newValue {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try SMAppService.mainApp.unregister()
                                    }
                                } catch {
                                    print("Failed to toggle launch at login: \(error)")
                                    launchAtLogin = SMAppService.mainApp.status == .enabled
                                }
                            }

                        Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                            .onChange(of: showMenuBarIcon) { _, newValue in
                                appState.showMenuBarIcon = newValue
                            }
                            
                        Toggle("Enable Safari Extension Integration", isOn: $extensionEnabled)
                            .onChange(of: extensionEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "extensionEnabled")
                                if newValue {
                                    ExtensionServer.shared.start()
                                } else {
                                    ExtensionServer.shared.stop()
                                }
                            }
                        
                        if extensionEnabled {
                            Button("Open Safari Settings to Enable Extension") {
                                SFSafariApplication.showPreferencesForExtension(withIdentifier: "com.freepass.app.FreePassExtension.Extension") { error in
                                    if let error = error {
                                        print("Error opening Safari preferences: \(error)")
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Default Password Generation")) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Length")
                                Spacer()
                                Text("\(Int(defaultPasswordLength))")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $defaultPasswordLength, in: 8...64, step: 1)
                                .onChange(of: defaultPasswordLength) { _, newValue in
                                    UserDefaults.standard.set(Int(newValue), forKey: "defaultPasswordLength")
                                }
                        }
                        Toggle("Uppercase (A-Z)", isOn: $defaultPasswordUppercase)
                            .onChange(of: defaultPasswordUppercase) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "defaultPasswordUppercase")
                            }
                        Toggle("Lowercase (a-z)", isOn: $defaultPasswordLowercase)
                            .onChange(of: defaultPasswordLowercase) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "defaultPasswordLowercase")
                            }
                        Toggle("Digits (0-9)", isOn: $defaultPasswordDigits)
                            .onChange(of: defaultPasswordDigits) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "defaultPasswordDigits")
                            }
                        Toggle("Symbols (!@#$)", isOn: $defaultPasswordSymbols)
                            .onChange(of: defaultPasswordSymbols) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "defaultPasswordSymbols")
                            }
                    }
                    
                    Section(header: Text("Data")) {
                        Button("Export to CSV (Unencrypted)...") {
                            activeAlert = .csvWarning
                        }
                        Button("Export Encrypted Backup...") {
                            exportEncryptedBackup()
                        }
                        Button("Import from CSV...") {
                            importFromCSV()
                        }
                        Button("Import Encrypted Backup...") {
                            importEncryptedBackup()
                        }
                    }
                    
                    Section(header: Text("Vault")) {
                        Button("Change Master Password...") {
                            activeAlert = .comingSoon("Master Password change will be available in the next release.")
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("Settings")
                .toolbarBackground(.hidden) // Fixes the 'navigationBar' is unavailable error
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 400)
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .csvWarning:
                return Alert(
                    title: Text("Security Warning"),
                    message: Text("This CSV file will contain all of your passwords in plain text. Anyone with access to this file can read your passwords. Only export to a secure location, and delete the file immediately after you are done."),
                    primaryButton: .destructive(Text("Export Unencrypted")) {
                        exportToCSV()
                    },
                    secondaryButton: .cancel()
                )
            case .comingSoon(let message):
                return Alert(title: Text("Coming Soon"), message: Text(message), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            lockTimeout = appState.lockTimeout
            clearClipboardDelay = appState.clearClipboardDelay
            lockOnSleep = appState.lockOnSleep
            touchIDEnabled = appState.touchIDEnabled
            showMenuBarIcon = appState.showMenuBarIcon
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    
    private func exportToCSV() {
        guard let key = appState.derivedKey else { return }
        
        do {
            let items = try modelContext.fetch(SwiftData.FetchDescriptor<VaultItem>())
            var csvString = "Title,Username,Password,URL,Category,Notes\n"
            
            for item in items {
                let title = item.title.replacingOccurrences(of: "\"", with: "\"\"")
                let user = item.username.replacingOccurrences(of: "\"", with: "\"\"")
                let pass = (item.decryptedPassword(using: key) ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let url = item.url.replacingOccurrences(of: "\"", with: "\"\"")
                let cat = item.category.replacingOccurrences(of: "\"", with: "\"\"")
                let notes = (item.decryptedNotes(using: key) ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                
                csvString += "\"\(title)\",\"\(user)\",\"\(pass)\",\"\(url)\",\"\(cat)\",\"\(notes)\"\n"
            }
            
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "FreePass_Export.csv"
            
            if panel.runModal() == .OK, let url = panel.url {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to export items: \(error)")
        }
    }
    
    // Defines a struct matching VaultItem precisely to allow for JSON serialization
    struct BackupItem: Codable {
        let id: UUID
        let title: String
        let username: String
        let encryptedPassword: Data
        let url: String
        let encryptedNotes: Data?
        let encryptedCardNumber: Data?
        let encryptedCardExpiration: Data?
        let encryptedCardCVV: Data?
        let category: String
        let isFavorite: Bool
        let isArchived: Bool
        let isTrashed: Bool
        let trashedAt: Date?
        let createdAt: Date
        let updatedAt: Date
    }

    private func exportEncryptedBackup() {
        guard let key = appState.derivedKey else { return }
        
        do {
            let items = try modelContext.fetch(SwiftData.FetchDescriptor<VaultItem>())
            
            let backupItems = items.map {
                BackupItem(
                    id: $0.id, title: $0.title, username: $0.username,
                    encryptedPassword: $0.encryptedPassword, url: $0.url,
                    encryptedNotes: $0.encryptedNotes, encryptedCardNumber: $0.encryptedCardNumber,
                    encryptedCardExpiration: $0.encryptedCardExpiration, encryptedCardCVV: $0.encryptedCardCVV,
                    category: $0.category, isFavorite: $0.isFavorite, isArchived: $0.isArchived,
                    isTrashed: $0.isTrashed, trashedAt: $0.trashedAt, createdAt: $0.createdAt, updatedAt: $0.updatedAt
                )
            }
            
            let jsonData = try JSONEncoder().encode(backupItems)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            let encryptedData = try CryptoManager.encrypt(jsonString, using: key)
            
            let panel = NSSavePanel()
            panel.allowedContentTypes = []
            panel.nameFieldStringValue = "FreePass_Backup.freepass"
            
            if panel.runModal() == .OK, let url = panel.url {
                try encryptedData.write(to: url, options: .atomic)
            }
        } catch {
            print("Failed to export encrypted backup: \(error)")
        }
    }
    
    private func importFromCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let csvString = try String(contentsOf: url, encoding: .utf8)
                parseAndImportCSV(csvString)
            } catch {
                print("Failed to read CSV file: \(error)")
            }
        }
    }
    
    private func parseAndImportCSV(_ csvString: String) {
        guard let key = appState.derivedKey else { return }
        
        // Handle carriage returns and split by newlines robustly
        let rawLines = csvString.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard rawLines.count > 1 else { return }
        
        // Dynamically locate headers for universal compatibility (Chrome, 1Password, FreePass native, etc)
        let headers = parseCSVLine(rawLines[0]).map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "\" \t\r\n")) }
        let titleIdx = headers.firstIndex { $0.contains("title") || $0.contains("name") } ?? 0
        let usernameIdx = headers.firstIndex { $0.contains("user") || $0.contains("login") } ?? 1
        let passwordIdx = headers.firstIndex { $0.contains("pass") } ?? 2
        let urlIdx = headers.firstIndex { $0 == "url" || $0.contains("website") || $0.contains("site") } ?? 3
        let categoryIdx = headers.firstIndex { $0.contains("category") || $0.contains("type") }
        let notesIdx = headers.firstIndex { $0.contains("note") }
        
        let dataLines = rawLines.dropFirst()
        
        for line in dataLines {
            let components = parseCSVLine(line)
            
            // Extract and clean strings, stripping both whitespaces AND explicit CSV wrapper quotes
            let title = components.count > titleIdx ? components[titleIdx].trimmingCharacters(in: CharacterSet(charactersIn: "\" \t\r\n")) : "Imported Item"
            let username = components.count > usernameIdx ? components[usernameIdx].trimmingCharacters(in: CharacterSet(charactersIn: "\" \t\r\n")) : ""
            let password = components.count > passwordIdx ? components[passwordIdx].trimmingCharacters(in: CharacterSet(charactersIn: "\" \t\r\n")) : ""
            let url = components.count > urlIdx ? components[urlIdx].trimmingCharacters(in: CharacterSet(charactersIn: "\" \t\r\n")) : ""
            let category = (categoryIdx != nil && components.count > categoryIdx!) ? components[categoryIdx!].trimmingCharacters(in: CharacterSet(charactersIn: "\" \t\r\n")) : "Login"
            let notes = (notesIdx != nil && components.count > notesIdx!) ? components[notesIdx!].trimmingCharacters(in: CharacterSet(charactersIn: "\" \t\r\n")) : ""
            
            // Only require a password or title to count as a valid row
            if !password.isEmpty || !title.isEmpty {
                // Ensure case-sensitive parity with native VaultCategory enumeration
                let matchedCategory = VaultCategory.allCases.first { $0.rawValue.lowercased() == category.lowercased() }
                let strictCategory = matchedCategory?.rawValue ?? "Login"
                let finalUrl = url.hasPrefix("http") || url.isEmpty ? url : "https://\(url)"
                
                guard let encryptedPassword = try? CryptoManager.encrypt(password, using: key) else { continue }
                let encryptedNotes = notes.isEmpty ? nil : (try? CryptoManager.encrypt(notes, using: key))
                
                let newItem = VaultItem(
                    title: title,
                    username: username,
                    encryptedPassword: encryptedPassword,
                    url: finalUrl,
                    encryptedNotes: encryptedNotes,
                    category: strictCategory
                )
                
                modelContext.insert(newItem)
            }
        }
        
        try? modelContext.save()
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result = [String]()
        var current = ""
        var insideQuotes = false
        
        let ArrayChar = Array(line)
        var i = 0
        while i < ArrayChar.count {
            let char = ArrayChar[i]
            if char == "\"" {
                if insideQuotes, i + 1 < ArrayChar.count, ArrayChar[i + 1] == "\"" {
                    // Escaped quote
                    current.append("\"")
                    i += 1
                } else {
                    insideQuotes.toggle()
                }
            } else if char == ",", !insideQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
            i += 1
        }
        result.append(current)
        return result
    }
    
    private func importEncryptedBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                guard let key = appState.derivedKey else { return }
                
                let encryptedData = try Data(contentsOf: url)
                let jsonString = try CryptoManager.decrypt(encryptedData, using: key)
                guard let jsonData = jsonString.data(using: .utf8) else { return }
                
                let backupItems = try JSONDecoder().decode([BackupItem].self, from: jsonData)
                
                for backupItem in backupItems {
                    let newItem = VaultItem(
                        title: backupItem.title,
                        username: backupItem.username,
                        encryptedPassword: backupItem.encryptedPassword,
                        url: backupItem.url,
                        encryptedNotes: backupItem.encryptedNotes,
                        encryptedCardNumber: backupItem.encryptedCardNumber,
                        encryptedCardExpiration: backupItem.encryptedCardExpiration,
                        encryptedCardCVV: backupItem.encryptedCardCVV,
                        category: backupItem.category,
                        isFavorite: backupItem.isFavorite,
                        isArchived: backupItem.isArchived,
                        isTrashed: backupItem.isTrashed,
                        trashedAt: backupItem.trashedAt
                    )
                    newItem.id = backupItem.id
                    newItem.createdAt = backupItem.createdAt
                    newItem.updatedAt = backupItem.updatedAt
                    
                    modelContext.insert(newItem)
                }
                
                try modelContext.save()
            } catch {
                print("Failed to import encrypted backup: \(error)")
            }
        }
    }
}

enum SettingsAlert: Identifiable {
    case csvWarning
    case comingSoon(String)
    
    var id: String {
        switch self {
        case .csvWarning: return "csvWarning"
        case .comingSoon(let msg): return "comingSoon_\(msg)"
        }
    }
}
