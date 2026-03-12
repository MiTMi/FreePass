import SwiftUI
import AppKit

/// Displays the details of a single vault item with copy/reveal/edit/delete actions.
struct VaultDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var showPassword = false
    @State private var revealedFields: Set<String> = []
    @State private var showNotes = false
    @State private var isEditing = false
    @State private var copiedField: String?

    let item: VaultItem
    var onDelete: (() -> Void)?

    private var cat: VaultCategory {
        VaultCategory(rawValue: item.category) ?? .login
    }

    private var decryptedPassword: String {
        guard let key = appState.derivedKey else { return "••••••••" }
        return item.decryptedPassword(using: key) ?? "Decryption failed"
    }

    private var decryptedNotes: String? {
        guard let key = appState.derivedKey else { return nil }
        return item.decryptedNotes(using: key)
    }

    private var decryptedCardNumber: String? {
        guard let key = appState.derivedKey else { return nil }
        return item.decryptedCardNumber(using: key)
    }

    private var decryptedCardExpiration: String? {
        guard let key = appState.derivedKey else { return nil }
        return item.decryptedCardExpiration(using: key)
    }

    private var decryptedCardCVV: String? {
        guard let key = appState.derivedKey else { return nil }
        return item.decryptedCardCVV(using: key)
    }

    private var decryptedFields: [String: String] {
        guard let key = appState.derivedKey else { return [:] }
        return item.decryptedFields(using: key) ?? [:]
    }

    var body: some View {
        ZStack {
            Color.fpDetail.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    detailsSection
                    if decryptedNotes != nil || cat == .secureNote {
                        notesSection
                    }
                    metadataSection
                    dangerSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $isEditing) {
            AddEditItemView(mode: .edit(item))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            FaviconView(
                urlString: item.url,
                category: cat,
                size: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.fpTextPrimary)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
            }

            Spacer()

            Button {
                item.isFavorite.toggle()
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .foregroundColor(item.isFavorite ? .yellow : .fpTextSecondary)
            }
            .buttonStyle(.plain)
            .help("Toggle favorite")

            Button { isEditing = true } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.fpAccentBlue)
            }
            .buttonStyle(.plain)
            .help("Edit item")
        }
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        switch cat {
        case .login:
            loginSection
        case .creditCard:
            creditCardSection
        case .secureNote:
            EmptyView()  // secureNote goes straight to notesSection
        default:
            genericSection
        }
    }

    // MARK: - Login

    private var loginSection: some View {
        VStack(spacing: 0) {
            if !item.url.isEmpty {
                detailRow(label: "Website", value: item.url, icon: "globe", isSecure: false, copiable: true)
                Button { openAndFill() } label: {
                    HStack {
                        Image(systemName: "safari.fill")
                        Text(copiedField == "open_fill" ? "Filling..." : "Open & Fill")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(copiedField == "open_fill" ? .white : .fpAccentPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(copiedField == "open_fill" ? Color.fpSuccess : Color.fpAccentPurple.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                Divider().background(Color.fpSurfaceBorder)
            }
            detailRow(label: "Username", value: item.username, icon: "person", isSecure: false, copiable: true)
            Divider().background(Color.fpSurfaceBorder)
            secureDetailRow(label: "Password", value: decryptedPassword, fieldKey: "password", icon: "key.fill", showGenerator: false)
        }
        .fpCard()
    }

    // MARK: - Credit Card

    private var creditCardSection: some View {
        VStack(spacing: 0) {
            if let num = decryptedCardNumber, !num.isEmpty {
                secureDetailRow(label: "Card Number", value: num, fieldKey: "cardNumber", icon: "creditcard", showGenerator: false)
                Divider().background(Color.fpSurfaceBorder)
            }
            if let exp = decryptedCardExpiration, !exp.isEmpty {
                detailRow(label: "Expiration", value: exp, icon: "calendar", isSecure: false, copiable: true)
                Divider().background(Color.fpSurfaceBorder)
            }
            if let cvv = decryptedCardCVV, !cvv.isEmpty {
                secureDetailRow(label: "CVV", value: cvv, fieldKey: "cvv", icon: "lock.fill", showGenerator: false)
            }
            // Extra fields (cardholder, bank, card type)
            ForEach(Array(cat.fieldSpecs.enumerated()), id: \.element.id) { index, spec in
                if let value = decryptedFields[spec.id], !value.isEmpty {
                    Divider().background(Color.fpSurfaceBorder)
                    detailRow(label: spec.label, value: value, icon: spec.sfSymbol, isSecure: spec.isSecure, copiable: true)
                }
            }
        }
        .fpCard()
    }

    // MARK: - Generic (all other categories)

    private var genericSection: some View {
        VStack(spacing: 0) {
            let specs = cat.fieldSpecs
            let filledSpecs = specs.filter { spec in
                !(decryptedFields[spec.id] ?? "").isEmpty
            }

            if filledSpecs.isEmpty {
                Text("No details saved yet. Tap edit to add information.")
                    .font(.system(size: 13))
                    .foregroundColor(.fpTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                ForEach(Array(filledSpecs.enumerated()), id: \.element.id) { index, spec in
                    let value = decryptedFields[spec.id] ?? ""
                    if index > 0 {
                        Divider().background(Color.fpSurfaceBorder)
                    }
                    if spec.isSecure {
                        secureDetailRow(
                            label: spec.label,
                            value: value,
                            fieldKey: spec.id,
                            icon: spec.sfSymbol,
                            showGenerator: false
                        )
                    } else {
                        detailRow(
                            label: spec.label,
                            value: value,
                            icon: spec.sfSymbol,
                            isSecure: false,
                            copiable: true
                        )
                    }
                }
            }
        }
        .fpCard()
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.fpAccentPurple)
                    .frame(width: 20)
                Text(cat == .secureNote ? "Note Content" : "Notes")
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
                Spacer()
                Button { showNotes.toggle() } label: {
                    Image(systemName: showNotes ? "eye.slash" : "eye")
                        .foregroundColor(.fpTextSecondary)
                }
                .buttonStyle(.plain)
            }

            if showNotes, let notes = decryptedNotes {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(.fpTextPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Click the eye icon to reveal \(cat == .secureNote ? "note" : "notes")")
                    .font(.system(size: 12))
                    .foregroundColor(.fpTextTertiary)
            }
        }
        .fpCard()
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Created").font(.caption).foregroundColor(.fpTextSecondary)
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundColor(.fpTextTertiary)
            }
            .padding(.vertical, 8).padding(.horizontal, 16)

            Divider().background(Color.fpSurfaceBorder)

            HStack {
                Text("Last Modified").font(.caption).foregroundColor(.fpTextSecondary)
                Spacer()
                Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundColor(.fpTextTertiary)
            }
            .padding(.vertical, 8).padding(.horizontal, 16)
        }
        .fpCard()
    }

    // MARK: - Danger

    private var dangerSection: some View {
        Button(role: .destructive) { onDelete?() } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Item")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.fpDanger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .fpCard()
    }

    // MARK: - Row Helpers

    private func detailRow(label: String, value: String, icon: String, isSecure: Bool, copiable: Bool) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.fpAccentPurple)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption).foregroundColor(.fpTextSecondary)
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.fpTextPrimary)
                    .textSelection(.enabled)
                    .lineLimit(isSecure ? 1 : nil)
            }

            Spacer()

            if copiable {
                copyButton(value: value, field: label.lowercased())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private func secureDetailRow(label: String, value: String, fieldKey: String, icon: String, showGenerator: Bool) -> some View {
        let isRevealed = revealedFields.contains(fieldKey)

        return HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.fpAccentPurple)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption).foregroundColor(.fpTextSecondary)
                if isRevealed {
                    Text(value)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.fpTextPrimary)
                        .textSelection(.enabled)
                } else {
                    Text("••••••••••••")
                        .font(.system(size: 14))
                        .foregroundColor(.fpTextSecondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    if isRevealed { revealedFields.remove(fieldKey) }
                    else { revealedFields.insert(fieldKey) }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundColor(.fpTextSecondary)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide" : "Show")

                copyButton(value: value, field: fieldKey)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private func copyButton(value: String, field: String) -> some View {
        Button {
            ClipboardManager.shared.copy(value)
            copiedField = field
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedField == field { copiedField = nil }
            }
        } label: {
            Image(systemName: copiedField == field ? "checkmark" : "doc.on.doc")
                .foregroundColor(copiedField == field ? .fpSuccess : .fpTextSecondary)
                .animation(.easeOut(duration: 0.2), value: copiedField)
        }
        .buttonStyle(.plain)
        .help("Copy \(field)")
    }

    // MARK: - Open & Fill

    private func openAndFill() {
        let urlString = item.url.lowercased().hasPrefix("http") ? item.url : "https://\(item.url)"
        guard let url = URL(string: urlString) else { return }

        withAnimation(.easeOut(duration: 0.2)) { copiedField = "open_fill" }

        let cleanDomain = item.url.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .components(separatedBy: "/").first ?? item.url
        ExtensionServer.shared.pendingAutoFillDomain = cleanDomain
        NSWorkspace.shared.open(url)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                if copiedField == "open_fill" { copiedField = nil }
            }
        }
    }
}
