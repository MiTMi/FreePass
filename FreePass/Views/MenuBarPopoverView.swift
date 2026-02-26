import SwiftUI
import SwiftData

/// Menu bar popover for quick access to vault items.
struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VaultItem.updatedAt, order: .reverse) private var items: [VaultItem]

    @State private var searchText = ""
    @State private var copiedItemID: UUID?

    private var filteredItems: [VaultItem] {
        if searchText.isEmpty {
            return Array(items.prefix(10))
        }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !appState.isUnlocked {
                lockedView
            } else {
                unlockedView
            }
        }
        .frame(width: 320, height: 400)
        .background(Color.fpSurface)
    }

    // MARK: - Locked State

    private var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.fpGradient)
            Text("Vault is Locked")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.fpTextPrimary)
            Text("Open FreePass to unlock")
                .font(.caption)
                .foregroundColor(.fpTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Unlocked State

    private var unlockedView: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.fpTextTertiary)
                TextField("Search vault...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(10)
            .background(Color.fpBackground)

            Divider().background(Color.fpSurfaceBorder)

            // Items
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundColor(.fpTextTertiary)
                    Text("No items found")
                        .font(.caption)
                        .foregroundColor(.fpTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems, id: \.id) { item in
                            menuBarItemRow(item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider().background(Color.fpSurfaceBorder)

            // Footer
            HStack {
                Button {
                    appState.lock()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text("Lock")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.fpTextSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(items.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.fpTextTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func menuBarItemRow(_ item: VaultItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: VaultCategory(rawValue: item.category)?.icon ?? "doc.fill")
                .font(.system(size: 13))
                .foregroundColor(.fpAccentPurple)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.fpTextPrimary)
                    .lineLimit(1)
                Text(item.username)
                    .font(.system(size: 10))
                    .foregroundColor(.fpTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Copy password button
            Button {
                if let key = appState.derivedKey,
                   let password = item.decryptedPassword(using: key) {
                    ClipboardManager.shared.copy(password)
                    copiedItemID = item.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedItemID == item.id { copiedItemID = nil }
                    }
                }
            } label: {
                Image(systemName: copiedItemID == item.id ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(copiedItemID == item.id ? .fpSuccess : .fpTextTertiary)
            }
            .buttonStyle(.plain)
            .help("Copy password")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}
