import SwiftUI
import SwiftData

/// Sheet for adding or editing a vault item.
struct AddEditItemView: View {
    enum Mode {
        case add(initialCategory: VaultCategory = .login)
        case edit(VaultItem)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    // ── Login / legacy fields ──────────────────────────────────────────────
    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    // Credit card legacy
    @State private var cardNumber = ""
    @State private var cardExpiration = ""
    @State private var cardCVV = ""

    // ── Generic fields for all other categories ────────────────────────────
    @State private var fieldValues: [String: String] = [:]

    @State private var category: VaultCategory = .login
    @State private var isFavorite = false
    @State private var showPassword = false
    @State private var showSecureFields: Set<String> = []
    @State private var showGenerator = false
    @State private var errorMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isFormValid: Bool {
        guard !title.isEmpty else { return false }
        switch category {
        case .login:      return !password.isEmpty
        case .creditCard: return !cardNumber.isEmpty
        default:          return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
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

            // ── Form ────────────────────────────────────────────────────────
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
                        .pickerStyle(.menu)
                        .background(Color.fpSurfaceHover)
                        .cornerRadius(6)
                    }

                    // Title (all categories)
                    formField(
                        label: titleLabel,
                        placeholder: titlePlaceholder,
                        text: $title
                    )

                    // ── Category-specific fields ───────────────────────────
                    Group {
                        switch category {
                        case .login:
                            loginFields
                        case .secureNote:
                            EmptyView() // just title + notes below
                        case .creditCard:
                            creditCardFields
                        default:
                            dynamicFields
                        }
                    }

                    // ── Notes (all categories except secureNote, which uses it as main content) ──
                    if category == .secureNote {
                        notesEditor(label: "Note Content", minHeight: 180)
                    } else {
                        notesEditor(label: "Notes", minHeight: 80)
                    }

                    // Favorite toggle
                    Toggle(isOn: $isFavorite) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill").foregroundColor(.yellow)
                            Text("Mark as favorite").foregroundColor(.fpTextPrimary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.fpAccentPurple)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.fpDanger)
                    }
                }
                .padding(20)
            }

            Divider().background(Color.fpSurfaceBorder)

            // ── Actions ─────────────────────────────────────────────────────
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button { saveItem() } label: {
                    Text(isEditing ? "Save Changes" : "Add Item")
                }
                .buttonStyle(FPGradientButtonStyle(isEnabled: isFormValid))
                .disabled(!isFormValid)
                .frame(width: 160)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 500, height: 640)
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

    // MARK: - Title helpers

    private var titleLabel: String {
        switch category {
        case .creditCard: return "Card Name"
        case .bankAccount: return "Account Name"
        case .softwareLicense: return "License Name"
        default: return "Title"
        }
    }

    private var titlePlaceholder: String {
        switch category {
        case .login:              return "e.g. Google Account"
        case .secureNote:         return "e.g. Travel Notes"
        case .creditCard:         return "e.g. Chase Sapphire"
        case .identity:           return "e.g. Personal Identity"
        case .password:           return "e.g. Social Media Password"
        case .document:           return "e.g. Lease Agreement"
        case .sshKey:             return "e.g. GitHub SSH Key"
        case .apiCredentials:     return "e.g. Stripe API"
        case .bankAccount:        return "e.g. Chase Checking"
        case .cryptoWallet:       return "e.g. My ETH Wallet"
        case .database:           return "e.g. Production DB"
        case .driverLicense:      return "e.g. California Driver's License"
        case .email:              return "e.g. Work Gmail"
        case .medicalRecord:      return "e.g. Annual Checkup 2025"
        case .membership:         return "e.g. Costco Membership"
        case .outdoorLicense:     return "e.g. Montana Fishing License"
        case .passport:           return "e.g. US Passport"
        case .rewards:            return "e.g. Delta SkyMiles"
        case .server:             return "e.g. Production Web Server"
        case .socialSecurityNumber: return "e.g. My SSN"
        case .softwareLicense:    return "e.g. Adobe Creative Cloud"
        case .wirelessRouter:     return "e.g. Home Router"
        default:                  return "e.g. My Item"
        }
    }

    // MARK: - Login Fields

    private var loginFields: some View {
        Group {
            formField(label: "Website URL", placeholder: "e.g. https://google.com", text: $url)
            formField(label: "Username / Email", placeholder: "e.g. user@example.com", text: $username)
            passwordField
        }
    }

    private var passwordField: some View {
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

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.fpTextSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Button { showGenerator = true } label: {
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
                            .fill(level.rawValue <= strength.rawValue ? strength.color : Color.fpSurfaceBorder)
                            .frame(height: 3)
                    }
                }
                Text(strength.label)
                    .font(.caption2)
                    .foregroundColor(strength.color)
            }
        }
    }

    // MARK: - Credit Card Fields

    private var creditCardFields: some View {
        Group {
            formField(label: "Card Number", placeholder: "e.g. 4111 1111 1111 1111", text: $cardNumber)
            HStack(spacing: 16) {
                formField(label: "Expiration", placeholder: "MM/YY", text: $cardExpiration)
                formField(label: "CVV", placeholder: "123", text: $cardCVV)
            }
            // Extra fields from fieldSpecs (cardholder name, bank, card type)
            ForEach(category.fieldSpecs) { spec in
                genericFieldView(spec: spec)
            }
        }
    }

    // MARK: - Dynamic Fields (all other categories)

    private var dynamicFields: some View {
        ForEach(category.fieldSpecs) { spec in
            genericFieldView(spec: spec)
        }
    }

    @ViewBuilder
    private func genericFieldView(spec: CategoryFieldSpec) -> some View {
        let binding = Binding(
            get: { fieldValues[spec.id] ?? "" },
            set: { fieldValues[spec.id] = $0.isEmpty ? nil : $0 }
        )

        VStack(alignment: .leading, spacing: 6) {
            Text(spec.label)
                .font(.caption)
                .foregroundColor(.fpTextSecondary)

            if spec.isMultiline {
                TextEditor(text: binding)
                    .font(.system(size: 13, design: spec.isSecure ? .monospaced : .default))
                    .frame(minHeight: 70)
                    .padding(8)
                    .background(Color.fpBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.fpSurfaceBorder, lineWidth: 1))
            } else if spec.isSecure {
                HStack(spacing: 8) {
                    if showSecureFields.contains(spec.id) {
                        TextField(spec.placeholder, text: binding)
                            .fpTextField()
                            .font(.system(size: 13, design: .monospaced))
                    } else {
                        SecureField(spec.placeholder, text: binding)
                            .fpTextField()
                    }
                    Button {
                        if showSecureFields.contains(spec.id) {
                            showSecureFields.remove(spec.id)
                        } else {
                            showSecureFields.insert(spec.id)
                        }
                    } label: {
                        Image(systemName: showSecureFields.contains(spec.id) ? "eye.slash" : "eye")
                            .foregroundColor(.fpTextSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    // Generator button for password-type fields
                    if spec.id == "password" {
                        Button { showGenerator = true } label: {
                            Image(systemName: "key.fill")
                                .foregroundColor(.fpAccentPurple)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help("Generate password")
                    }
                }
            } else {
                TextField(spec.placeholder, text: binding)
                    .fpTextField()
            }
        }
    }

    // MARK: - Notes Editor

    private func notesEditor(label: String, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.fpTextSecondary)
            TextEditor(text: $notes)
                .font(.system(size: 13))
                .frame(minHeight: minHeight)
                .padding(8)
                .background(Color.fpBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.fpSurfaceBorder, lineWidth: 1))
        }
    }

    // MARK: - Generic text field helper

    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.fpTextSecondary)
            TextField(placeholder, text: text)
                .fpTextField()
        }
    }

    // MARK: - Load Existing Data

    private func loadExistingData() {
        switch mode {
        case .add(let initialCategory):
            category = initialCategory
        case .edit(let item):
            title = item.title
            username = item.username
            url = item.url
            isFavorite = item.isFavorite
            category = VaultCategory(rawValue: item.category) ?? .login

            if let key = appState.derivedKey {
                password = item.decryptedPassword(using: key) ?? ""
                notes    = item.decryptedNotes(using: key) ?? ""
                cardNumber     = item.decryptedCardNumber(using: key) ?? ""
                cardExpiration = item.decryptedCardExpiration(using: key) ?? ""
                cardCVV        = item.decryptedCardCVV(using: key) ?? ""
                fieldValues    = item.decryptedFields(using: key) ?? [:]
            }
        }
    }

    // MARK: - Save

    private func saveItem() {
        guard let key = appState.derivedKey else {
            errorMessage = "Vault is locked."
            return
        }

        do {
            let encPwd  = try CryptoManager.encrypt(password, using: key)
            let encNote: Data? = notes.isEmpty ? nil : try CryptoManager.encrypt(notes, using: key)
            let encCard: Data? = cardNumber.isEmpty     ? nil : try CryptoManager.encrypt(cardNumber, using: key)
            let encExp:  Data? = cardExpiration.isEmpty ? nil : try CryptoManager.encrypt(cardExpiration, using: key)
            let encCVV:  Data? = cardCVV.isEmpty        ? nil : try CryptoManager.encrypt(cardCVV, using: key)

            // Generic fields dict — filter empty values
            let nonEmpty = fieldValues.filter { !$0.value.isEmpty }
            let encFields: Data? = nonEmpty.isEmpty ? nil : try VaultItem.encryptFields(nonEmpty, using: key)

            // Derive the subtitle (username field in list) from the most relevant field
            let derivedSubtitle = subtitleForCurrentCategory()

            switch mode {
            case .add:
                let newItem = VaultItem(
                    title: title,
                    username: derivedSubtitle,
                    encryptedPassword: encPwd,
                    url: url,
                    encryptedNotes: encNote,
                    encryptedCardNumber: encCard,
                    encryptedCardExpiration: encExp,
                    encryptedCardCVV: encCVV,
                    encryptedFields: encFields,
                    category: category.rawValue,
                    isFavorite: isFavorite
                )
                modelContext.insert(newItem)

            case .edit(let item):
                item.title = title
                item.username = derivedSubtitle
                item.encryptedPassword = encPwd
                item.url = url
                item.encryptedNotes = encNote
                item.encryptedCardNumber = encCard
                item.encryptedCardExpiration = encExp
                item.encryptedCardCVV = encCVV
                item.encryptedFields = encFields
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

    /// Returns the best subtitle string to display in the vault list for the current category.
    private func subtitleForCurrentCategory() -> String {
        switch category {
        case .login:
            return username
        case .creditCard:
            let last4 = cardNumber.filter(\.isNumber).suffix(4)
            return last4.isEmpty ? username : "•••• \(last4)"
        default:
            if let key = category.subtitleFieldKey {
                return fieldValues[key] ?? ""
            }
            return username
        }
    }
}
