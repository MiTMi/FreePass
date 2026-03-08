import SwiftUI
import SwiftData

/// 1Password-style add/edit sheet.
struct AddEditItemView: View {
    enum Mode {
        case add(initialCategory: VaultCategory = .login)
        case edit(VaultItem)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    // ── Persisted data states ───────────────────────────────────────────────
    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var cardNumber = ""
    @State private var cardExpiration = ""
    @State private var cardCVV = ""
    @State private var fieldValues: [String: String] = [:]

    @State private var category: VaultCategory = .login
    @State private var isFavorite = false

    // ── UI States ───────────────────────────────────────────────────────────
    @State private var showPassword = false
    @State private var showSecureFields: Set<String> = []
    @State private var showGenerator = false
    @State private var showCategoryPicker = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

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

    // MARK: - Palette

    private let bgColor      = Color(red: 0.14, green: 0.14, blue: 0.18)
    private let cardColor    = Color(red: 0.17, green: 0.17, blue: 0.21)
    private let dividerColor = Color(white: 0.28)
    private let labelColor   = Color(white: 0.55)
    private let blueAccent   = Color(red: 0.27, green: 0.55, blue: 0.98)
    private let redAccent    = Color(red: 0.95, green: 0.30, blue: 0.30)

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                formHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        iconTitleRow
                        categoryFieldsSection
                        addMoreRow
                        notesCard
                        addLocationRow
                        tagsSection
                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 72)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .frame(width: 480, height: 700)
        .onAppear { loadExistingData(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { titleFocused = true } }
        .sheet(isPresented: $showGenerator) {
            PasswordGeneratorView(onUsePassword: { pw in
                password = pw
                showGenerator = false
            })
            .frame(width: 420, height: 480)
        }
    }

    // MARK: - Header

    private var formHeader: some View {
        ZStack {
            Text(isEditing ? "Edit Item" : "New Item")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                }
                .buttonStyle(.plain)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(bgColor)
    }

    // MARK: - Icon + Title row

    private var iconTitleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // Category icon with dropdown chevron
            Button {
                showCategoryPicker.toggle()
            } label: {
                VStack(spacing: 2) {
                    CategoryIcon(category, size: 52)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(white: 0.55))
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showCategoryPicker, arrowEdge: .bottom) {
                categoryPickerPopover
            }

            // Large title field with blue border
            TextField(category == .creditCard ? "Card Name" : "Title", text: $title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .textFieldStyle(.plain)
                .focused($titleFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(titleFocused ? blueAccent : Color.clear, lineWidth: 2)
                )
        }
    }

    // MARK: - Category picker popover

    private var categoryPickerPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(VaultCategory.itemCategories) { cat in
                    Button {
                        category = cat
                        showCategoryPicker = false
                    } label: {
                        HStack(spacing: 10) {
                            CategoryIcon(cat, size: 28)
                            Text(cat.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                            Spacer()
                            if cat == category {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(blueAccent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(cat == category ? Color.white.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .frame(width: 240, height: 360)
        .background(Color(red: 0.16, green: 0.16, blue: 0.20))
    }

    // MARK: - Category Fields Section

    @ViewBuilder
    private var categoryFieldsSection: some View {
        switch category {
        case .secureNote:
            EmptyView() // notes card is the main content

        case .login:
            loginFieldsCard

        case .creditCard:
            creditCardFieldsCard

        default:
            if !category.fieldSpecs.isEmpty {
                genericFieldsCard
            }
        }
    }

    // MARK: - Login Card

    private var loginFieldsCard: some View {
        VStack(spacing: 0) {
            oneFieldRow(label: "Website URL", placeholder: "https://example.com",
                        text: urlBinding, isSecure: false, fieldKey: "url")
            divider
            oneFieldRow(label: "Username", placeholder: "user@example.com",
                        text: usernameBinding, isSecure: false, fieldKey: "username")
            divider
            passwordRow(label: "Password", value: $password, fieldKey: "password")
        }
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Credit Card Card

    private var creditCardFieldsCard: some View {
        VStack(spacing: 0) {
            oneFieldRow(label: "Card Number", placeholder: "4111 1111 1111 1111",
                        text: cardNumberBinding, isSecure: true, fieldKey: "cardNumber")
            divider
            oneFieldRow(label: "Expiration", placeholder: "MM/YY",
                        text: cardExpirationBinding, isSecure: false, fieldKey: "cardExpiration")
            divider
            oneFieldRow(label: "CVV", placeholder: "123",
                        text: cardCVVBinding, isSecure: true, fieldKey: "cardCVV")

            // Extra fields from spec (cardholder, bank, type)
            ForEach(category.fieldSpecs) { spec in
                divider
                dynamicFieldRow(spec: spec)
            }
        }
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Generic Fields Card

    private var genericFieldsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(category.fieldSpecs.enumerated()), id: \.element.id) { index, spec in
                if index > 0 { divider }
                if spec.isMultiline {
                    multilineFieldRow(spec: spec)
                } else {
                    dynamicFieldRow(spec: spec)
                }
            }
        }
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Field Row Builders

    /// Standard single-line field row (1Password style: label on top, value below)
    @ViewBuilder
    private func oneFieldRow(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        fieldKey: String
    ) -> some View {
        HStack(spacing: 10) {
            dragHandle
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(labelColor)
                if isSecure && !showSecureFields.contains(fieldKey) {
                    HStack {
                        SecureField(placeholder, text: text)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        eyeButton(fieldKey: fieldKey)
                        if fieldKey == "password" || fieldKey == "cardCVV" || fieldKey == "cardNumber" {
                            // no generator for card fields
                        }
                    }
                } else {
                    HStack {
                        TextField(placeholder, text: text)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        if isSecure { eyeButton(fieldKey: fieldKey) }
                        if fieldKey == "password" { generatorButton }
                    }
                }
            }
            Spacer()
            clearButton { text.wrappedValue = "" }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func passwordRow(label: String, value: Binding<String>, fieldKey: String) -> some View {
        HStack(spacing: 10) {
            dragHandle
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(labelColor)
                HStack {
                    Group {
                        if showPassword {
                            TextField("Password", text: value)
                        } else {
                            SecureField("Password", text: value)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(labelColor)
                    }
                    .buttonStyle(.plain)

                    generatorButton
                }

                if !password.isEmpty {
                    let strength = PasswordGenerator.evaluateStrength(password)
                    HStack(spacing: 3) {
                        ForEach(PasswordStrength.allCases, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(level.rawValue <= strength.rawValue ? strength.color : Color.white.opacity(0.15))
                                .frame(height: 2.5)
                        }
                        Text(strength.label)
                            .font(.system(size: 10))
                            .foregroundColor(strength.color)
                    }
                    .padding(.top, 2)
                }
            }
            clearButton { password = "" }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func dynamicFieldRow(spec: CategoryFieldSpec) -> some View {
        let binding = fieldValueBinding(for: spec.id)
        return HStack(spacing: 10) {
            dragHandle
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(labelColor)
                HStack {
                    if spec.isSecure && !showSecureFields.contains(spec.id) {
                        SecureField(spec.placeholder, text: binding)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        TextField(spec.placeholder, text: binding)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    if spec.isSecure { eyeButton(fieldKey: spec.id) }
                    if spec.id == "password" { generatorButton }
                }
            }
            Spacer()
            clearButton { fieldValues[spec.id] = nil }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func multilineFieldRow(spec: CategoryFieldSpec) -> some View {
        let binding = fieldValueBinding(for: spec.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                dragHandle
                Text(spec.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(labelColor)
                Spacer()
                clearButton { fieldValues[spec.id] = nil }
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)

            TextEditor(text: binding)
                .font(.system(size: 13, design: spec.isSecure ? .monospaced : .default))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(.white)
                .frame(minHeight: 70)
                .padding(.horizontal, 14)
                .padding(.bottom, 11)
        }
    }

    // MARK: - Shared Row Subviews

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11))
            .foregroundColor(Color(white: 0.35))
            .frame(width: 18)
    }

    private var divider: some View {
        Rectangle()
            .fill(dividerColor.opacity(0.35))
            .frame(height: 1)
            .padding(.leading, 42)
    }

    private func clearButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 17))
                .foregroundColor(redAccent.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    private func eyeButton(fieldKey: String) -> some View {
        Button {
            if showSecureFields.contains(fieldKey) {
                showSecureFields.remove(fieldKey)
            } else {
                showSecureFields.insert(fieldKey)
            }
        } label: {
            Image(systemName: showSecureFields.contains(fieldKey) ? "eye.slash" : "eye")
                .font(.system(size: 12))
                .foregroundColor(labelColor)
        }
        .buttonStyle(.plain)
    }

    private var generatorButton: some View {
        Button { showGenerator = true } label: {
            Image(systemName: "key.fill")
                .font(.system(size: 12))
                .foregroundColor(blueAccent.opacity(0.9))
        }
        .buttonStyle(.plain)
        .help("Generate password")
    }

    // MARK: - "add more" Row

    private var addMoreRow: some View {
        HStack {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(blueAccent)
            Text("add more")
                .font(.system(size: 14))
                .foregroundColor(blueAccent)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 11))
                .foregroundColor(labelColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if category != .secureNote {
                Text("notes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(labelColor)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add any notes about this item here.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.4))
                        .padding(.horizontal, 16)
                        .padding(.vertical, category == .secureNote ? 16 : 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .frame(minHeight: category == .secureNote ? 130 : 80)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - "add a location" row

    private var addLocationRow: some View {
        HStack {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(blueAccent)
            Text("add a location")
                .font(.system(size: 14))
                .foregroundColor(blueAccent)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Tags section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tags")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(labelColor)
                .padding(.leading, 2)

            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(blueAccent)
                Text("Add tag")
                    .font(.system(size: 13))
                    .foregroundColor(blueAccent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.22))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Bottom Save Bar

    private var bottomBar: some View {
        HStack {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(redAccent)
            } else {
                // Favorite toggle (compact)
                Toggle(isOn: $isFavorite) {
                    HStack(spacing: 5) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : Color(white: 0.55))
                        Text("Favorite")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.55))
                    }
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.55))
                .padding(.trailing, 12)

            Button {
                saveItem()
            } label: {
                Text(isEditing ? "Save" : "Save")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(isFormValid ? blueAccent : blueAccent.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.16).opacity(0.96))
                .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            Rectangle().fill(dividerColor.opacity(0.3)).frame(height: 1)
        }
    }

    // MARK: - Bindings

    private var urlBinding: Binding<String> { Binding(get: { url }, set: { url = $0 }) }
    private var usernameBinding: Binding<String> { Binding(get: { username }, set: { username = $0 }) }
    private var cardNumberBinding: Binding<String> { Binding(get: { cardNumber }, set: { cardNumber = $0 }) }
    private var cardExpirationBinding: Binding<String> { Binding(get: { cardExpiration }, set: { cardExpiration = $0 }) }
    private var cardCVVBinding: Binding<String> { Binding(get: { cardCVV }, set: { cardCVV = $0 }) }

    private func fieldValueBinding(for key: String) -> Binding<String> {
        Binding(
            get: { fieldValues[key] ?? "" },
            set: { fieldValues[key] = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Load Existing Data

    private func loadExistingData() {
        switch mode {
        case .add(let initialCategory):
            category = initialCategory
            title = initialCategory.rawValue  // pre-fill with category name, 1Password style
        case .edit(let item):
            title = item.title
            username = item.username
            url = item.url
            isFavorite = item.isFavorite
            category = VaultCategory(rawValue: item.category) ?? .login
            if let key = appState.derivedKey {
                password = item.decryptedPassword(using: key) ?? ""
                notes = item.decryptedNotes(using: key) ?? ""
                cardNumber = item.decryptedCardNumber(using: key) ?? ""
                cardExpiration = item.decryptedCardExpiration(using: key) ?? ""
                cardCVV = item.decryptedCardCVV(using: key) ?? ""
                fieldValues = item.decryptedFields(using: key) ?? [:]
            }
        }
    }

    // MARK: - Save

    private func saveItem() {
        guard let key = appState.derivedKey else { errorMessage = "Vault is locked."; return }
        do {
            let encPwd   = try CryptoManager.encrypt(password, using: key)
            let encNote: Data? = notes.isEmpty ? nil : try CryptoManager.encrypt(notes, using: key)
            let encCard: Data? = cardNumber.isEmpty ? nil : try CryptoManager.encrypt(cardNumber, using: key)
            let encExp:  Data? = cardExpiration.isEmpty ? nil : try CryptoManager.encrypt(cardExpiration, using: key)
            let encCVV:  Data? = cardCVV.isEmpty ? nil : try CryptoManager.encrypt(cardCVV, using: key)
            let nonEmpty = fieldValues.filter { !$0.value.isEmpty }
            let encFields: Data? = nonEmpty.isEmpty ? nil : try VaultItem.encryptFields(nonEmpty, using: key)
            let subtitle = subtitleForCurrentCategory()

            switch mode {
            case .add:
                modelContext.insert(VaultItem(
                    title: title, username: subtitle,
                    encryptedPassword: encPwd, url: url,
                    encryptedNotes: encNote,
                    encryptedCardNumber: encCard, encryptedCardExpiration: encExp, encryptedCardCVV: encCVV,
                    encryptedFields: encFields,
                    category: category.rawValue, isFavorite: isFavorite
                ))
            case .edit(let item):
                item.title = title; item.username = subtitle
                item.encryptedPassword = encPwd; item.url = url
                item.encryptedNotes = encNote
                item.encryptedCardNumber = encCard; item.encryptedCardExpiration = encExp; item.encryptedCardCVV = encCVV
                item.encryptedFields = encFields
                item.category = category.rawValue; item.isFavorite = isFavorite
                item.updatedAt = Date()
            }
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func subtitleForCurrentCategory() -> String {
        switch category {
        case .login:      return username
        case .creditCard:
            let last4 = cardNumber.filter(\.isNumber).suffix(4)
            return last4.isEmpty ? (fieldValues["cardholderName"] ?? "") : "•••• \(last4)"
        default:
            if let key = category.subtitleFieldKey { return fieldValues[key] ?? "" }
            return username
        }
    }
}
