import SwiftUI
import SwiftData

struct AddEditItemView: View {
    enum Mode {
        case add(initialCategory: VaultCategory = .login)
        case edit(VaultItem)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    // Persisted
    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var cardNumber = ""
    @State private var cardExpiration = ""
    @State private var cardCVV = ""
    @State private var fieldValues: [String: String] = [:]
    @State private var customFields: [CustomField] = []
    @State private var tags: [String] = []
    @State private var category: VaultCategory = .login
    @State private var isFavorite = false

    // Field ordering
    @State private var fieldOrder: [String] = []
    @State private var draggedFieldId: String?
    @State private var draggedCustomId: UUID?

    // UI
    @State private var showPassword = false
    @State private var showSecureFields: Set<String> = []
    @State private var showGenerator = false
    @State private var showCategoryPicker = false
    @State private var addMoreExpanded = false
    @State private var showLocationField = false
    @State private var showTagInput = false
    @State private var tagDraft = ""
    @State private var newFieldLabel = ""
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    // Palette
    private let bg    = Color(red: 0.14, green: 0.14, blue: 0.18)
    private let card  = Color(red: 0.17, green: 0.17, blue: 0.21)
    private let div   = Color(white: 0.28)
    private let lbl   = Color(white: 0.55)
    private let blue  = Color(red: 0.27, green: 0.55, blue: 0.98)
    private let red   = Color(red: 0.95, green: 0.30, blue: 0.30)

    private var isEditing: Bool { if case .edit = mode { return true }; return false }
    private var isFormValid: Bool {
        guard !title.isEmpty else { return false }
        switch category {
        case .login:      return !password.isEmpty
        case .creditCard: return !cardNumber.isEmpty
        default:          return true
        }
    }
    private var orderedSpecs: [CategoryFieldSpec] {
        let specs = category.fieldSpecs
        guard !fieldOrder.isEmpty else { return specs }
        let map = Dictionary(uniqueKeysWithValues: specs.map { ($0.id, $0) })
        return fieldOrder.compactMap { map[$0] }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        iconTitleRow
                        categoryFields
                        addMoreSection
                        notesCard
                        locationSection
                        tagsSection
                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 80)
                }
            }
            bottomBar
        }
        .frame(width: 480, height: 700)
        .onAppear {
            loadData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { titleFocused = true }
        }
        .sheet(isPresented: $showGenerator) {
            PasswordGeneratorView(onUsePassword: { pw in password = pw; showGenerator = false })
                .frame(width: 420, height: 480)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(isEditing ? "Edit Item" : "New Item")
                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium)).foregroundColor(lbl)
                }.buttonStyle(.plain)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .medium)).foregroundColor(lbl)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14).background(bg)
    }

    // MARK: - Icon + Title

    private var iconTitleRow: some View {
        HStack(spacing: 12) {
            Button { showCategoryPicker.toggle() } label: {
                VStack(spacing: 2) {
                    CategoryIcon(category, size: 52)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundColor(lbl)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showCategoryPicker, arrowEdge: .bottom) { categoryPopover }

            TextField(category == .creditCard ? "Card Name" : "Title", text: $title)
                .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                .textFieldStyle(.plain).focused($titleFocused)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(card)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(titleFocused ? blue : Color.clear, lineWidth: 2))
        }
    }

    private var categoryPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(VaultCategory.itemCategories) { cat in
                    Button {
                        category = cat
                        fieldOrder = cat.fieldSpecs.map { $0.id }
                        showCategoryPicker = false
                    } label: {
                        HStack(spacing: 10) {
                            CategoryIcon(cat, size: 28)
                            Text(cat.rawValue).font(.system(size: 13)).foregroundColor(.white)
                            Spacer()
                            if cat == category { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(blue) }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(cat == category ? Color.white.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                }
            }.padding(10)
        }
        .frame(width: 240, height: 360)
        .background(Color(red: 0.16, green: 0.16, blue: 0.20))
    }

    // MARK: - Category-specific fields

    @ViewBuilder
    private var categoryFields: some View {
        switch category {
        case .secureNote: EmptyView()
        case .login:
            fieldsCard {
                fieldRow(label: "Website URL", placeholder: "https://example.com", text: .init(get: { url }, set: { url = $0 }), secure: false, key: "url")
                dividerLine
                fieldRow(label: "Username", placeholder: "user@example.com", text: .init(get: { username }, set: { username = $0 }), secure: false, key: "username")
                dividerLine
                passwordFieldRow
            }
        case .creditCard:
            fieldsCard {
                fieldRow(label: "Card Number", placeholder: "4111 1111 1111 1111", text: .init(get: { cardNumber }, set: { cardNumber = $0 }), secure: true, key: "cnum")
                dividerLine
                fieldRow(label: "Expiration", placeholder: "MM/YY", text: .init(get: { cardExpiration }, set: { cardExpiration = $0 }), secure: false, key: "cexp")
                dividerLine
                fieldRow(label: "CVV", placeholder: "123", text: .init(get: { cardCVV }, set: { cardCVV = $0 }), secure: true, key: "ccvv")
                ForEach(category.fieldSpecs) { spec in dividerLine; specRow(spec) }
            }
        default:
            if !orderedSpecs.isEmpty {
                fieldsCard {
                    ForEach(Array(orderedSpecs.enumerated()), id: \.element.id) { i, spec in
                        if i > 0 { dividerLine }
                        specRow(spec)
                            .onDrag { draggedFieldId = spec.id; return NSItemProvider(object: spec.id as NSString) }
                            .onDrop(of: [.plainText], delegate: CategoryFieldDropDelegate(targetId: spec.id, fieldOrder: $fieldOrder, draggedId: $draggedFieldId))
                    }
                }
            }
        }
    }

    private func fieldsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - "add more" (custom fields)

    private var addMoreSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { addMoreExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold)).foregroundColor(blue)
                    Text("add more").font(.system(size: 14)).foregroundColor(blue)
                    Spacer()
                    Image(systemName: addMoreExpanded ? "chevron.up" : "chevron.down").font(.system(size: 11)).foregroundColor(lbl)
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 12)

            if !customFields.isEmpty || addMoreExpanded {
                dividerLine
                ForEach(Array(customFields.enumerated()), id: \.element.id) { i, _ in
                    if i > 0 { dividerLine }
                    customFieldRow(i)
                        .onDrag { draggedCustomId = customFields[i].id; return NSItemProvider(object: customFields[i].id.uuidString as NSString) }
                        .onDrop(of: [.plainText], delegate: CustomFieldDropDelegate(targetId: customFields[i].id, fields: $customFields, draggedId: $draggedCustomId))
                }
                if addMoreExpanded {
                    if !customFields.isEmpty { dividerLine }
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 17)).foregroundColor(blue)
                        TextField("Field name…", text: $newFieldLabel)
                            .textFieldStyle(.plain).font(.system(size: 14)).foregroundColor(.white)
                            .onSubmit { addCustomField() }
                        Button("Add") { addCustomField() }
                            .buttonStyle(.plain).font(.system(size: 13, weight: .medium))
                            .foregroundColor(newFieldLabel.isEmpty ? lbl : blue).disabled(newFieldLabel.isEmpty)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
        }
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func customFieldRow(_ i: Int) -> some View {
        HStack(spacing: 10) {
            dragHandle
            VStack(alignment: .leading, spacing: 2) {
                TextField("Field name", text: Binding(get: { customFields[i].label }, set: { customFields[i].label = $0 }))
                    .textFieldStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundColor(lbl)
                HStack {
                    let key = "cf_\(customFields[i].id)"
                    if customFields[i].isSecure && !showSecureFields.contains(key) {
                        SecureField("Value", text: Binding(get: { customFields[i].value }, set: { customFields[i].value = $0 }))
                            .textFieldStyle(.plain).font(.system(size: 14)).foregroundColor(.white)
                    } else {
                        TextField("Value", text: Binding(get: { customFields[i].value }, set: { customFields[i].value = $0 }))
                            .textFieldStyle(.plain).font(.system(size: 14)).foregroundColor(.white)
                    }
                    eyeBtn(key)
                    Button { customFields[i].isSecure.toggle() } label: {
                        Image(systemName: customFields[i].isSecure ? "lock.fill" : "lock.open").font(.system(size: 11)).foregroundColor(lbl)
                    }.buttonStyle(.plain).help("Toggle secure")
                }
            }
            Spacer()
            Button { let id = customFields[i].id; withAnimation { customFields.removeAll { $0.id == id } } } label: {
                Image(systemName: "minus.circle.fill").font(.system(size: 17)).foregroundColor(red.opacity(0.85))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func addCustomField() {
        guard !newFieldLabel.isEmpty else { return }
        withAnimation { customFields.append(CustomField(label: newFieldLabel)) }
        newFieldLabel = ""
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if category != .secureNote {
                Text("notes").font(.system(size: 12, weight: .medium)).foregroundColor(lbl)
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
            }
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add any notes about this item here.")
                        .font(.system(size: 14)).foregroundColor(Color(white: 0.4))
                        .padding(.horizontal, 16).padding(.vertical, category == .secureNote ? 16 : 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .font(.system(size: 14)).scrollContentBackground(.hidden).background(Color.clear).foregroundColor(.white)
                    .frame(minHeight: category == .secureNote ? 130 : 80)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .background(card).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Location

    @ViewBuilder
    private var locationSection: some View {
        if category != .login {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showLocationField.toggle() }
                } label: {
                    HStack {
                        Image(systemName: showLocationField ? "minus" : "plus").font(.system(size: 12, weight: .semibold)).foregroundColor(blue)
                        Text(showLocationField ? "remove location" : "add a location").font(.system(size: 14)).foregroundColor(blue)
                        Spacer()
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 12)

                if showLocationField {
                    dividerLine
                    HStack(spacing: 10) {
                        Image(systemName: "globe").font(.system(size: 13)).foregroundColor(lbl).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("URL").font(.system(size: 12, weight: .medium)).foregroundColor(lbl)
                            TextField("https://example.com", text: $url)
                                .textFieldStyle(.plain).font(.system(size: 14)).foregroundColor(.white)
                        }
                        if !url.isEmpty {
                            Button { url = "" } label: {
                                Image(systemName: "minus.circle.fill").font(.system(size: 17)).foregroundColor(red.opacity(0.85))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                }
            }
            .background(card).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("tags").font(.system(size: 12, weight: .medium)).foregroundColor(lbl).padding(.leading, 2)

            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag).font(.system(size: 12)).foregroundColor(.white)
                            Button { withAnimation { tags.removeAll { $0 == tag } } } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundColor(lbl)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(white: 0.28)).clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }

            if showTagInput {
                HStack(spacing: 8) {
                    TextField("Tag name…", text: $tagDraft)
                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(white: 0.22)).clipShape(RoundedRectangle(cornerRadius: 20))
                        .onSubmit { submitTag() }
                    Button("Add") { submitTag() }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                        .foregroundColor(tagDraft.isEmpty ? lbl : blue).disabled(tagDraft.isEmpty)
                    Button { showTagInput = false; tagDraft = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(lbl)
                    }.buttonStyle(.plain)
                }
            } else {
                Button { withAnimation { showTagInput = true } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .semibold)).foregroundColor(blue)
                        Text("Add tag").font(.system(size: 13)).foregroundColor(blue)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(white: 0.22)).clipShape(RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
        }
    }

    private func submitTag() {
        let t = tagDraft.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !tags.contains(t) else { tagDraft = ""; return }
        withAnimation { tags.append(t) }
        tagDraft = ""; showTagInput = false
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            if let e = errorMessage {
                Text(e).font(.caption).foregroundColor(red)
            } else {
                Toggle(isOn: $isFavorite) {
                    HStack(spacing: 5) {
                        Image(systemName: isFavorite ? "star.fill" : "star").foregroundColor(isFavorite ? .yellow : lbl)
                        Text("Favorite").font(.system(size: 12)).foregroundColor(lbl)
                    }
                }.toggleStyle(.button).buttonStyle(.plain)
            }
            Spacer()
            Button("Cancel") { dismiss() }.buttonStyle(.plain).font(.system(size: 14)).foregroundColor(lbl).padding(.trailing, 12)
            Button { saveItem() } label: {
                Text("Save").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 8)
                    .background(isFormValid ? blue : blue.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain).disabled(!isFormValid).keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16).opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(div.opacity(0.3)).frame(height: 1) }
    }

    // MARK: - Reusable row components

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal").font(.system(size: 11)).foregroundColor(Color(white: 0.35)).frame(width: 18)
    }

    private var dividerLine: some View {
        Rectangle().fill(div.opacity(0.35)).frame(height: 1).padding(.leading, 42)
    }

    private func eyeBtn(_ key: String) -> some View {
        Button {
            if showSecureFields.contains(key) { showSecureFields.remove(key) } else { showSecureFields.insert(key) }
        } label: {
            Image(systemName: showSecureFields.contains(key) ? "eye.slash" : "eye").font(.system(size: 12)).foregroundColor(lbl)
        }.buttonStyle(.plain)
    }

    private var genBtn: some View {
        Button { showGenerator = true } label: {
            Image(systemName: "key.fill").font(.system(size: 12)).foregroundColor(blue.opacity(0.9))
        }.buttonStyle(.plain).help("Generate password")
    }

    private func minusBtn(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill").font(.system(size: 17)).foregroundColor(red.opacity(0.85))
        }.buttonStyle(.plain)
    }

    /// Generic field row (URL, username, card fields)
    private func fieldRow(label: String, placeholder: String, text: Binding<String>, secure: Bool, key: String) -> some View {
        HStack(spacing: 10) {
            dragHandle
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(lbl)
                HStack {
                    if secure && !showSecureFields.contains(key) {
                        SecureField(placeholder, text: text).textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).foregroundColor(.white)
                    } else {
                        TextField(placeholder, text: text).textFieldStyle(.plain).font(.system(size: 14)).foregroundColor(.white)
                    }
                    if secure { eyeBtn(key) }
                }
            }
            Spacer()
            minusBtn { text.wrappedValue = "" }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var passwordFieldRow: some View {
        HStack(spacing: 10) {
            dragHandle
            VStack(alignment: .leading, spacing: 2) {
                Text("Password").font(.system(size: 12, weight: .medium)).foregroundColor(lbl)
                HStack {
                    Group {
                        if showPassword { TextField("Password", text: $password) }
                        else { SecureField("Password", text: $password) }
                    }.textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).foregroundColor(.white)
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye").font(.system(size: 12)).foregroundColor(lbl)
                    }.buttonStyle(.plain)
                    genBtn
                }
                if !password.isEmpty {
                    let s = PasswordGenerator.evaluateStrength(password)
                    HStack(spacing: 3) {
                        ForEach(PasswordStrength.allCases, id: \.self) { lvl in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(lvl.rawValue <= s.rawValue ? s.color : Color.white.opacity(0.15)).frame(height: 2.5)
                        }
                        Text(s.label).font(.system(size: 10)).foregroundColor(s.color)
                    }.padding(.top, 2)
                }
            }
            Spacer()
            minusBtn { password = "" }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func specRow(_ spec: CategoryFieldSpec) -> some View {
        HStack(spacing: 10) {
            dragHandle
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.label).font(.system(size: 12, weight: .medium)).foregroundColor(lbl)
                if spec.isMultiline {
                    TextEditor(text: fvb(spec.id))
                        .font(.system(size: 13, design: spec.isSecure ? .monospaced : .default))
                        .scrollContentBackground(.hidden).background(Color.clear).foregroundColor(.white).frame(minHeight: 60)
                } else {
                    HStack {
                        if spec.isSecure && !showSecureFields.contains(spec.id) {
                            SecureField(spec.placeholder, text: fvb(spec.id))
                                .textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).foregroundColor(.white)
                        } else {
                            TextField(spec.placeholder, text: fvb(spec.id))
                                .textFieldStyle(.plain).font(.system(size: 14)).foregroundColor(.white)
                        }
                        if spec.isSecure { eyeBtn(spec.id) }
                        if spec.id == "password" { genBtn }
                    }
                }
            }
            Spacer()
            minusBtn { fieldValues[spec.id] = nil }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: - Bindings helper

    private func fvb(_ key: String) -> Binding<String> {
        Binding(get: { fieldValues[key] ?? "" }, set: { fieldValues[key] = $0.isEmpty ? nil : $0 })
    }

    // MARK: - Load / Save

    private func loadData() {
        switch mode {
        case .add(let cat):
            category = cat
            title = cat.rawValue
            fieldOrder = cat.fieldSpecs.map { $0.id }
        case .edit(let item):
            category = VaultCategory(rawValue: item.category) ?? .login
            title = item.title; username = item.username; url = item.url
            showLocationField = !item.url.isEmpty && category != .login
            isFavorite = item.isFavorite
            fieldOrder = category.fieldSpecs.map { $0.id }
            guard let key = appState.derivedKey else { return }
            password = item.decryptedPassword(using: key) ?? ""
            notes = item.decryptedNotes(using: key) ?? ""
            cardNumber = item.decryptedCardNumber(using: key) ?? ""
            cardExpiration = item.decryptedCardExpiration(using: key) ?? ""
            cardCVV = item.decryptedCardCVV(using: key) ?? ""
            var all = item.decryptedFields(using: key) ?? [:]
            // Extract custom fields
            if let cfJson = all.removeValue(forKey: "__custom"),
               let cfData = cfJson.data(using: .utf8),
               let cfs = try? JSONDecoder().decode([CustomField].self, from: cfData) {
                customFields = cfs
            }
            // Extract tags
            if let tagsStr = all.removeValue(forKey: "__tags") {
                tags = tagsStr.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            }
            fieldValues = all
        }
    }

    private func saveItem() {
        guard let key = appState.derivedKey else { errorMessage = "Vault is locked."; return }
        do {
            let encPwd  = try CryptoManager.encrypt(password, using: key)
            let encNote: Data? = notes.isEmpty ? nil : try CryptoManager.encrypt(notes, using: key)
            let encCard: Data? = cardNumber.isEmpty ? nil : try CryptoManager.encrypt(cardNumber, using: key)
            let encExp:  Data? = cardExpiration.isEmpty ? nil : try CryptoManager.encrypt(cardExpiration, using: key)
            let encCVV:  Data? = cardCVV.isEmpty ? nil : try CryptoManager.encrypt(cardCVV, using: key)

            var extra = fieldValues.filter { !$0.value.isEmpty }
            // Serialize custom fields
            if !customFields.isEmpty, let cfData = try? JSONEncoder().encode(customFields), let cfStr = String(data: cfData, encoding: .utf8) {
                extra["__custom"] = cfStr
            }
            // Serialize tags
            if !tags.isEmpty { extra["__tags"] = tags.joined(separator: ",") }

            let encFields: Data? = extra.isEmpty ? nil : try VaultItem.encryptFields(extra, using: key)
            let subtitle = subtitleFor()

            switch mode {
            case .add:
                modelContext.insert(VaultItem(
                    title: title, username: subtitle, encryptedPassword: encPwd, url: url,
                    encryptedNotes: encNote, encryptedCardNumber: encCard,
                    encryptedCardExpiration: encExp, encryptedCardCVV: encCVV,
                    encryptedFields: encFields, category: category.rawValue, isFavorite: isFavorite
                ))
            case .edit(let item):
                item.title = title; item.username = subtitle
                item.encryptedPassword = encPwd; item.url = url
                item.encryptedNotes = encNote; item.encryptedCardNumber = encCard
                item.encryptedCardExpiration = encExp; item.encryptedCardCVV = encCVV
                item.encryptedFields = encFields; item.category = category.rawValue
                item.isFavorite = isFavorite; item.updatedAt = Date()
            }
            try modelContext.save(); dismiss()
        } catch { errorMessage = "Failed to save: \(error.localizedDescription)" }
    }

    private func subtitleFor() -> String {
        switch category {
        case .login: return username
        case .creditCard:
            let last4 = cardNumber.filter(\.isNumber).suffix(4)
            return last4.isEmpty ? "" : "•••• \(last4)"
        default:
            if let k = category.subtitleFieldKey { return fieldValues[k] ?? "" }
            return ""
        }
    }
}
