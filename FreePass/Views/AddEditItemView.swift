import SwiftUI
import SwiftData

/// Sheet for adding or editing a vault item.
struct AddEditItemView: View {
    enum Mode {
        case add
        case edit(VaultItem)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var category: VaultCategory = .login
    @State private var isFavorite = false
    @State private var showPassword = false
    @State private var showGenerator = false
    @State private var errorMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isFormValid: Bool {
        !title.isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Item" : "Add New Item")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.fpTextPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.fpTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().background(Color.fpSurfaceBorder)

            // Form
            ScrollView {
                VStack(spacing: 16) {
                    // Category picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.caption)
                            .foregroundColor(.fpTextSecondary)
                        Picker("", selection: $category) {
                            ForEach(VaultCategory.itemCategories, id: \.self) { cat in
                                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Title
                    formField(label: "Title", placeholder: "e.g. Google Account", text: $title)

                    // URL
                    formField(label: "Website URL", placeholder: "e.g. https://google.com", text: $url)

                    // Username
                    formField(label: "Username / Email", placeholder: "e.g. user@example.com", text: $username)

                    // Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.fpTextSecondary)
                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .fpTextField()

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.fpTextSecondary)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)

                            Button {
                                showGenerator = true
                            } label: {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.fpAccentPurple)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .help("Generate password")
                        }

                        if !password.isEmpty {
                            let strength = PasswordGenerator.evaluateStrength(password)
                            HStack(spacing: 4) {
                                ForEach(PasswordStrength.allCases, id: \.self) { level in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(level.rawValue <= strength.rawValue
                                              ? strength.color
                                              : Color.fpSurfaceBorder)
                                        .frame(height: 3)
                                }
                            }
                            Text(strength.label)
                                .font(.caption2)
                                .foregroundColor(strength.color)
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.fpTextSecondary)
                        TextEditor(text: $notes)
                            .font(.system(size: 13))
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color.fpBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.fpSurfaceBorder, lineWidth: 1)
                            )
                    }

                    // Favorite toggle
                    Toggle(isOn: $isFavorite) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Mark as favorite")
                                .foregroundColor(.fpTextPrimary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.fpAccentPurple)

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.fpDanger)
                    }
                }
                .padding(20)
            }

            Divider().background(Color.fpSurfaceBorder)

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    saveItem()
                } label: {
                    Text(isEditing ? "Save Changes" : "Add Item")
                }
                .buttonStyle(FPGradientButtonStyle(isEnabled: isFormValid))
                .disabled(!isFormValid)
                .frame(width: 160)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 500, height: 620)
        .background(Color.fpSurface)
        .onAppear { loadExistingData() }
        .sheet(isPresented: $showGenerator) {
            PasswordGeneratorView(onUsePassword: { generated in
                password = generated
                showGenerator = false
            })
            .frame(width: 420, height: 480)
        }
    }

    // MARK: - Helpers

    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.fpTextSecondary)
            TextField(placeholder, text: text)
                .fpTextField()
        }
    }

    private func loadExistingData() {
        guard case .edit(let item) = mode else { return }
        title = item.title
        username = item.username
        url = item.url
        isFavorite = item.isFavorite
        category = VaultCategory(rawValue: item.category) ?? .login

        if let key = appState.derivedKey {
            password = item.decryptedPassword(using: key) ?? ""
            notes = item.decryptedNotes(using: key) ?? ""
        }
    }

    private func saveItem() {
        guard let key = appState.derivedKey else {
            errorMessage = "Vault is locked."
            return
        }

        do {
            let encryptedPassword = try CryptoManager.encrypt(password, using: key)
            let encryptedNotes: Data? = notes.isEmpty ? nil : try CryptoManager.encrypt(notes, using: key)

            switch mode {
            case .add:
                let newItem = VaultItem(
                    title: title,
                    username: username,
                    encryptedPassword: encryptedPassword,
                    url: url,
                    encryptedNotes: encryptedNotes,
                    category: category.rawValue,
                    isFavorite: isFavorite
                )
                modelContext.insert(newItem)

            case .edit(let item):
                item.title = title
                item.username = username
                item.encryptedPassword = encryptedPassword
                item.url = url
                item.encryptedNotes = encryptedNotes
                item.category = category.rawValue
                item.isFavorite = isFavorite
                item.updatedAt = Date()
            }

            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
