import SwiftUI
import AppKit

/// Displays the details of a single vault item with copy/reveal/edit/delete actions.
struct VaultDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var showPassword = false
    @State private var showNotes = false
    @State private var isEditing = false
    @State private var copiedField: String?

    let item: VaultItem
    var onDelete: (() -> Void)?

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

    var body: some View {
        ZStack {
            Color.fpDetail.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    let cat = VaultCategory(rawValue: item.category) ?? .login
                    if cat == .login || cat == .creditCard {
                        detailsSection
                    }
                    if item.encryptedNotes != nil {
                        notesSection
                    }
                    metadataSection
                    dangerSection
                }
                .padding(24)
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
                category: VaultCategory(rawValue: item.category) ?? .login,
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

            Button {
                isEditing = true
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.fpAccentBlue)
            }
            .buttonStyle(.plain)
            .help("Edit item")
        }
    }

    // MARK: - Credentials Section

    private var detailsSection: some View {
        let cat = VaultCategory(rawValue: item.category) ?? .login
        return VStack(spacing: 0) {
            if cat == .login {
                if !item.url.isEmpty {
                    detailRow(label: "Website", value: item.url, icon: "globe", copiable: true)
                    // Open & Fill action
                    Button {
                        openAndFill()
                    } label: {
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

                detailRow(label: "Username", value: item.username, icon: "person", copiable: true)
                Divider().background(Color.fpSurfaceBorder)

                // Password row (special handling for reveal toggle)
                HStack(alignment: .top) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.fpAccentPurple)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.fpTextSecondary)

                        HStack {
                            if showPassword {
                                Text(decryptedPassword)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.fpTextPrimary)
                                    .textSelection(.enabled)
                            } else {
                                Text("••••••••••••")
                                    .font(.system(size: 14))
                                    .foregroundColor(.fpTextSecondary)
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.fpTextSecondary)
                        }
                        .buttonStyle(.plain)
                        .help(showPassword ? "Hide password" : "Show password")

                        copyButton(value: decryptedPassword, field: "password")
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            } else if cat == .creditCard {
                if let num = decryptedCardNumber, !num.isEmpty {
                    detailRow(label: "Card Number", value: num, icon: "creditcard", copiable: true)
                    Divider().background(Color.fpSurfaceBorder)
                }
                if let exp = decryptedCardExpiration, !exp.isEmpty {
                    detailRow(label: "Expiration", value: exp, icon: "calendar", copiable: true)
                    Divider().background(Color.fpSurfaceBorder)
                }
                if let cvv = decryptedCardCVV, !cvv.isEmpty {
                    detailRow(label: "CVV", value: cvv, icon: "lock.fill", copiable: true)
                }
            }
        }
        .fpCard()
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.fpAccentPurple)
                    .frame(width: 20)
                Text("Notes")
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
                Spacer()
                Button {
                    showNotes.toggle()
                } label: {
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
                Text("Click the eye icon to reveal notes")
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
                Text("Created")
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.fpTextTertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)

            Divider().background(Color.fpSurfaceBorder)

            HStack {
                Text("Last Modified")
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
                Spacer()
                Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.fpTextTertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        .fpCard()
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        Button(role: .destructive) {
            onDelete?()
        } label: {
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

    // MARK: - Helpers

    private func detailRow(label: String, value: String, icon: String, copiable: Bool) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.fpAccentPurple)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.fpTextPrimary)
                    .textSelection(.enabled)
            }

            Spacer()

            if copiable {
                copyButton(value: value, field: label.lowercased())
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

    private func openAndFill() {
        let urlString = item.url.lowercased().hasPrefix("http") ? item.url : "https://\(item.url)"
        if let url = URL(string: urlString) {
            
            withAnimation(.easeOut(duration: 0.2)) {
                copiedField = "open_fill"
            }
            
            // Wait for Safari extension to wake up and ping localhost for this specific domain
            let cleanDomain = item.url.lowercased().replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").components(separatedBy: "/").first ?? item.url
            ExtensionServer.shared.pendingAutoFillDomain = cleanDomain
            
            // Open the browser directly
            NSWorkspace.shared.open(url)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.2)) {
                    if copiedField == "open_fill" { copiedField = nil }
                }
            }
        }
    }
}
