import SwiftUI
import SwiftData

/// Main vault view with three-column layout: categories, item list, and detail pane.
struct VaultListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VaultItem.updatedAt, order: .reverse) private var allItems: [VaultItem]

    @State private var selectedCategory: VaultCategory = .all
    @State private var selectedItem: VaultItem?
    @State private var searchText = ""
    @State private var showingAddItem = false
    @State private var showingGenerator = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var filteredItems: [VaultItem] {
        var result = allItems

        switch selectedCategory {
        case .all:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        default:
            result = result.filter { $0.category == selectedCategory.rawValue }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.username.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var categoryCounts: [VaultCategory: Int] {
        var counts: [VaultCategory: Int] = [:]
        counts[.all] = allItems.count
        counts[.favorites] = allItems.filter { $0.isFavorite }.count
        for cat in VaultCategory.itemCategories {
            counts[cat] = allItems.filter { $0.category == cat.rawValue }.count
        }
        return counts
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            itemList
        } detail: {
            detailPane
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search vault...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingAddItem = true } label: {
                    Image(systemName: "plus")
                }
                .help("Add new item")

                Button { showingGenerator = true } label: {
                    Image(systemName: "key.fill")
                }
                .help("Password generator")

                Button { appState.lock() } label: {
                    Image(systemName: "lock.fill")
                }
                .help("Lock vault")
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddEditItemView(mode: .add)
        }
        .sheet(isPresented: $showingGenerator) {
            PasswordGeneratorView()
                .frame(width: 420, height: 480)
        }
        .onAppear {
            appState.resetInactivityTimer()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedCategory) {
            Section("Categories") {
                ForEach([VaultCategory.all] + VaultCategory.itemCategories, id: \.self) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(.fpAccentPurple)
                            .frame(width: 20)
                        Text(category.rawValue)
                            .foregroundColor(.fpTextPrimary)
                        Spacer()
                        Text("\(categoryCounts[category, default: 0])")
                            .font(.caption)
                            .foregroundColor(.fpTextSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.fpSurfaceHover)
                            .clipShape(Capsule())
                    }
                    .tag(category)
                }
            }

            Section("Collections") {
                HStack {
                    Image(systemName: VaultCategory.favorites.icon)
                        .foregroundColor(.yellow)
                        .frame(width: 20)
                    Text("Favorites")
                        .foregroundColor(.fpTextPrimary)
                    Spacer()
                    Text("\(categoryCounts[.favorites, default: 0])")
                        .font(.caption)
                        .foregroundColor(.fpTextSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.fpSurfaceHover)
                        .clipShape(Capsule())
                }
                .tag(VaultCategory.favorites)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 190)
    }

    // MARK: - Item List

    private var itemList: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.fpTextTertiary)
                    Text(searchText.isEmpty ? "No items yet" : "No results found")
                        .font(.headline)
                        .foregroundColor(.fpTextSecondary)
                    if searchText.isEmpty {
                        Button("Add your first item") {
                            showingAddItem = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredItems, id: \.id, selection: $selectedItem) { item in
                    VaultItemRow(item: item)
                        .tag(item)
                        .contextMenu {
                            if let key = appState.derivedKey,
                               let password = item.decryptedPassword(using: key) {
                                Button("Copy Password") {
                                    ClipboardManager.shared.copy(password)
                                }
                            }
                            Button("Copy Username") {
                                ClipboardManager.shared.copy(item.username)
                            }
                            Divider()
                            Button("Toggle Favorite") {
                                item.isFavorite.toggle()
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deleteItem(item)
                            }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(minWidth: 260)
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        Group {
            if let item = selectedItem {
                VaultDetailView(item: item, onDelete: {
                    selectedItem = nil
                    deleteItem(item)
                })
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.fpGradient)
                    Text("Select an item to view details")
                        .font(.title3)
                        .foregroundColor(.fpTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func deleteItem(_ item: VaultItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// MARK: - Item Row

struct VaultItemRow: View {
    let item: VaultItem

    private var categoryIcon: String {
        VaultCategory(rawValue: item.category)?.icon ?? "doc.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.fpAccentPurple.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: categoryIcon)
                    .font(.system(size: 15))
                    .foregroundColor(.fpAccentPurple)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.fpTextPrimary)
                        .lineLimit(1)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                    }
                }
                Text(item.username)
                    .font(.system(size: 11))
                    .foregroundColor(.fpTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
