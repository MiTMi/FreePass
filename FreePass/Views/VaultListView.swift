import SwiftUI
import SwiftData

/// Sidebar selection type
enum SidebarSelection: Equatable {
    case category(VaultCategory)
    case archive
    case recentlyDeleted
}

/// Main vault view with three-column layout: categories, item list, and detail pane.
struct VaultListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VaultItem.updatedAt, order: .reverse) private var allItems: [VaultItem]

    @State private var selection: SidebarSelection = .category(.all)
    @State private var selectedItem: VaultItem?
    @State private var searchText = ""
    @State private var showingAddItem = false
    @State private var showingCategorySelection = false
    @State private var categoryToAdd: VaultCategory = .login
    @State private var showingGenerator = false

    private var filteredItems: [VaultItem] {
        var result = allItems

        switch selection {
        case .category(let cat):
            switch cat {
            case .all:
                result = result.filter { !$0.isTrashed && !$0.isArchived }
            case .favorites:
                result = result.filter { $0.isFavorite && !$0.isTrashed && !$0.isArchived }
            default:
                result = result.filter { $0.category == cat.rawValue && !$0.isTrashed && !$0.isArchived }
            }
        case .archive:
            result = result.filter { $0.isArchived && !$0.isTrashed }
        case .recentlyDeleted:
            result = result.filter { $0.isTrashed }
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
        let activeItems = allItems.filter { !$0.isTrashed && !$0.isArchived }
        
        counts[.all] = activeItems.count
        counts[.favorites] = activeItems.filter { $0.isFavorite }.count
        for cat in VaultCategory.itemCategories {
            counts[cat] = activeItems.filter { $0.category == cat.rawValue }.count
        }
        return counts
    }

    private var archiveCount: Int {
        allItems.filter { $0.isArchived && !$0.isTrashed }.count
    }

    private var deletedCount: Int {
        allItems.filter { $0.isTrashed }.count
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
                
            itemList
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 350)
                
            detailPane
                .frame(minWidth: 300, maxWidth: .infinity)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search vault...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingCategorySelection = true } label: {
                    Image(systemName: "plus")
                }
                .help("Add new item")

                Button { showingGenerator = true } label: {
                    Image(systemName: "key.fill")
                }
                .help("Password generator")

                #if os(macOS)
                SettingsLink {
                    Image(systemName: "gearshape.fill")
                }
                .help("Settings")
                #endif

                Button { appState.lock() } label: {
                    Image(systemName: "lock.fill")
                }
                .help("Lock vault")
            }
        }
        .sheet(isPresented: $showingCategorySelection) {
            CategorySelectionView(onSelect: { category in
                categoryToAdd = category
                showingAddItem = true
            })
        }
        .sheet(isPresented: $showingAddItem) {
            AddEditItemView(mode: .add(initialCategory: categoryToAdd))
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
        ZStack {
            Color.fpSidebar.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // User Profile Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.9))
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                    Text("michael.tubul")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.fpTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.fpTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .padding(.top, 10)
                
                // Profile
                SidebarRow(
                    icon: "person.crop.square.fill", iconColor: .blue,
                    title: "Profile", count: nil, isSelected: false
                ) {}
                .padding(.bottom, 8)
                
                // Main Category Group
                VStack(spacing: 2) {
                    SidebarRow(
                        icon: "tray.full.fill", iconColor: .gray,
                        title: "All Items", count: categoryCounts[.all, default: 0],
                        isSelected: selection == .category(.all),
                        isStaticPrimary: true
                    ) { selection = .category(.all) }
                    
                    SidebarRow(
                        icon: "star.fill", iconColor: .yellow,
                        title: "Favorites", count: categoryCounts[.favorites, default: 0],
                        isSelected: selection == .category(.favorites)
                    ) { selection = .category(.favorites) }
                    
                    SidebarRow(
                        icon: "tower.receptacle.fill", iconColor: .gray,
                        title: "Watchtower", count: nil, isSelected: false
                    ) {}
                    
                    SidebarRow(
                        icon: "chevron.left.forwardslash.chevron.right", iconColor: .teal,
                        title: "Developer", count: nil, isSelected: false
                    ) {}
                }
                .padding(.bottom, 16)
                
                // VAULTS Section
                SectionHeader(title: "VAULTS", icon: "chevron.down", actionIcon: "plus")
                VStack(spacing: 2) {
                    SidebarRow(
                        icon: "lock.circle.fill", iconColor: .gray,
                        title: "Personal", count: nil, isSelected: false
                    ) {}
                }
                .padding(.bottom, 16)
                
                // TAGS Section
                SectionHeader(title: "TAGS", icon: "chevron.down")
                VStack(spacing: 2) {
                    SidebarRow(
                        icon: "circle.fill", iconColor: .green,
                        title: "Starter Kit", count: nil, isSelected: false
                    ) {}
                }
                .padding(.bottom, 16)
                
                // Archive Section
                VStack(spacing: 2) {
                    SidebarRow(
                        icon: "archivebox.fill", iconColor: .gray,
                        title: "Archive", count: archiveCount, isSelected: selection == .archive
                    ) { selection = .archive }
                    
                    SidebarRow(
                        icon: "arrow.counterclockwise.circle", iconColor: .gray,
                        title: "Recently Deleted", count: deletedCount, isSelected: selection == .recentlyDeleted
                    ) { selection = .recentlyDeleted }
                }
                .padding(.bottom, 16)
                
                    Spacer(minLength: 40)
                }
            }
        }
    }

    // MARK: - Item List

    private var itemList: some View {
        ZStack {
            Color.fpList.ignoresSafeArea()
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
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            VaultItemRow(item: item, isSelected: selectedItem == item)
                                .onTapGesture {
                                    selectedItem = item
                                }
                                .contextMenu {
                                   if item.isTrashed {
                                       Button("Restore") {
                                           item.isTrashed = false
                                           item.trashedAt = nil
                                           try? modelContext.save()
                                       }
                                       Button("Delete permanently", role: .destructive) {
                                           if selectedItem == item { selectedItem = nil }
                                           modelContext.delete(item)
                                           try? modelContext.save()
                                       }
                                   } else {
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
                                        Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                            item.isFavorite.toggle()
                                        }
                                        Button(item.isArchived ? "Unarchive" : "Archive") {
                                            item.isArchived.toggle()
                                            try? modelContext.save()
                                            if selectedItem == item { selectedItem = nil }
                                        }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            deleteItem(item)
                                        }
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
                .animation(.default, value: filteredItems.count)
                }
            }
        }
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        ZStack {
            Color.fpDetail.ignoresSafeArea()
            Group {
                if let item = selectedItem {
                    VaultDetailView(item: item, onDelete: {
                        selectedItem = nil
                        deleteItem(item)
                    })
                } else {
                    VStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                        Text("Select an item to view details")
                            .font(.title3)
                            .foregroundColor(.fpTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func deleteItem(_ item: VaultItem) {
        if item.isTrashed {
            modelContext.delete(item)
        } else {
            item.isTrashed = true
            item.trashedAt = Date()
            if selectedItem == item { selectedItem = nil }
        }
        try? modelContext.save()
    }
}

// MARK: - Sidebar Components

private struct SectionHeader: View {
    let title: String
    let icon: String
    var actionIcon: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.fpTextSecondary)
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.fpTextSecondary)
                .padding(.leading, 2)
            
            Spacer()
            
            if let action = actionIcon {
                Image(systemName: action)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.fpTextPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(title == "VAULTS" ? Color.blue.opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 10)
    }
}

private struct SidebarRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int?
    let isSelected: Bool
    var isStaticPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : iconColor)
                .frame(width: 22)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .fpTextPrimary)
            
            Spacer()
            
            if let c = count, c > 0 {
                Text("\(c)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .fpSelection : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isSelected ? Color.white : Color(white: 0.3))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.fpSelection : (isHovering ? Color(white: 0.2) : Color.clear))
        .cornerRadius(8)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onHover { h in isHovering = h }
        .onTapGesture(perform: action)
    }
}

// MARK: - Item Row

struct VaultItemRow: View {
    let item: VaultItem
    var isSelected: Bool = false
    @State private var isHovering = false

    private var resolvedCategory: VaultCategory {
        VaultCategory(rawValue: item.category) ?? .login
    }

    var body: some View {
        HStack(spacing: 14) {
            // Category icon / Favicon
            FaviconView(urlString: item.url, category: resolvedCategory, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .fpTextPrimary)
                        .lineLimit(1)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                    }
                }
                Text(item.username)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .fpTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(minHeight: 56)
        .background(isSelected ? Color.fpSelection : (isHovering ? Color.fpSurfaceHover : Color.clear))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onHover { hover in isHovering = hover }
    }
}

// MARK: - Category Selection Grid

struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (VaultCategory) -> Void

    @State private var searchText = ""

    private var filteredMain: [VaultCategory] {
        guard !searchText.isEmpty else { return VaultCategory.mainCategories }
        return VaultCategory.mainCategories.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredOther: [VaultCategory] {
        guard !searchText.isEmpty else { return VaultCategory.otherCategories }
        return VaultCategory.otherCategories.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    let mainColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    let otherColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // ── Dark gradient background ──────────────────────────────────
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.14, blue: 0.22),
                    Color(red: 0.18, green: 0.18, blue: 0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // ── Title ─────────────────────────────────────────────
                    Text("What would you like to add?")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 44)
                        .padding(.horizontal, 32)

                    // ── Search bar ────────────────────────────────────────
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.45))

                        TextField("", text: $searchText, prompt:
                            Text("Try searching anything")
                                .foregroundColor(Color.white.opacity(0.40))
                        )
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 24)

                    // ── Main category grid ────────────────────────────────
                    if !filteredMain.isEmpty {
                        LazyVGrid(columns: mainColumns, spacing: 12) {
                            ForEach(filteredMain) { category in
                                MainCategoryCard(category: category)
                                    .onTapGesture {
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            onSelect(category)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // ── Separator ─────────────────────────────────────────
                    if !filteredMain.isEmpty && !filteredOther.isEmpty {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                    }

                    // ── Other categories grid ─────────────────────────────
                    if !filteredOther.isEmpty {
                        LazyVGrid(columns: otherColumns, spacing: 12) {
                            ForEach(filteredOther) { category in
                                OtherCategoryCard(category: category)
                                    .onTapGesture {
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            onSelect(category)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Empty state
                    if filteredMain.isEmpty && filteredOther.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(Color.white.opacity(0.3))
                            Text("No results for \"\(searchText)\"")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        .padding(.top, 40)
                    }

                    Spacer(minLength: 32)
                }
            }

            // ── × close button ────────────────────────────────────────────
            Button { dismiss() } label: {
                Text("×")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Color.white.opacity(0.55))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .frame(width: 540, height: 620)
    }
}

struct MainCategoryCard: View {
    let category: VaultCategory
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CategoryIcon(category, size: 52)

            Text(category.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.12 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(isHovering ? 0.22 : 0.10), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

struct OtherCategoryCard: View {
    let category: VaultCategory
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            CategoryIcon(category, size: 40)

            Text(category.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.12 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isHovering ? 0.22 : 0.10), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

