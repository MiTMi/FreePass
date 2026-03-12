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
    @State private var listCategoryFilter: VaultCategory = .all
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

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

        // Apply the middle-pane category filter
        if listCategoryFilter != .all {
            result = result.filter { $0.category == listCategoryFilter.rawValue }
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

    /// Groups filtered items by their creation month/year, sorted newest-first.
    private var groupedItems: [(key: String, items: [VaultItem])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredItems) { item -> Date in
            let comps = calendar.dateComponents([.year, .month], from: item.createdAt)
            return calendar.date(from: comps) ?? item.createdAt
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { (key: formatter.string(from: $0.key).uppercased(), items: $0.value) }
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

    private let titleBarHeight: CGFloat = 40
    private let contentTopPadding: CGFloat = 14
    private let trafficLightClearance: CGFloat = 80

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                .ignoresSafeArea(.container, edges: .top)
        } content: {
            itemList
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 350)
                .ignoresSafeArea(.container, edges: .top)
        } detail: {
            detailPane
                .navigationSplitViewColumnWidth(min: 300, ideal: 500, max: 1000)
                .ignoresSafeArea(.container, edges: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Color.fpList.ignoresSafeArea())
        .ignoresSafeArea()

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
        ZStack(alignment: .top) {
            Color.fpSidebar.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Integrated Title Bar Area with Traffic Light Clearance
                HStack(spacing: 14) {
                    Spacer().frame(width: trafficLightClearance)
                    
                    Button(action: { showingCategorySelection = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showingGenerator = true }) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    
                    #if os(macOS)
                    SettingsLink {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    #endif
                    
                    Button(action: { appState.lock() }) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .foregroundColor(.fpTextPrimary)
                .frame(height: titleBarHeight)
                .padding(.top, 4) // Nudge down from very edge
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: contentTopPadding)
                        
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
                        .padding(.bottom, 14)
                        
                        // Items
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
                        
                        SectionHeader(title: "VAULTS", icon: "chevron.down", actionIcon: "plus")
                        VStack(spacing: 2) {
                            SidebarRow(
                                icon: "lock.circle.fill", iconColor: .gray,
                                title: "Personal", count: nil, isSelected: false
                            ) {}
                        }
                        .padding(.bottom, 16)
                        
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
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
    }

    // MARK: - Item List

    private var itemList: some View {
        ZStack(alignment: .top) {
            Color.fpList.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Integrated Title Bar Area with Traffic Light Clearance and Category Filter
                HStack(spacing: 0) {
                    if columnVisibility != .all {
                        Spacer().frame(width: trafficLightClearance)
                    }
                    
                    categoryFilterHeader
                        .padding(.leading, 8)
                    
                    Spacer()
                }
                .frame(height: titleBarHeight)
                .padding(.top, 4)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: contentTopPadding)

                        if filteredItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                                    .font(.system(size: 36))
                                    .foregroundColor(.fpTextTertiary)
                                Text(searchText.isEmpty ? "No items yet" : "No results found")
                                    .font(.headline)
                                    .foregroundColor(.fpTextSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(groupedItems, id: \.key) { group in
                                    // Month/year section header
                                    HStack {
                                        Text(group.key)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.fpTextSecondary)
                                            .tracking(0.5)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.top, 18)
                                    .padding(.bottom, 6)

                                    ForEach(group.items) { item in
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
                            }
                            .padding(.horizontal, 8)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .animation(.default, value: filteredItems.count)
                }
            }
        }
    }

    // MARK: - Category Filter Header

    private var categoryFilterHeader: some View {
        HStack {
            Menu {
                // "All Categories" option
                Button {
                    listCategoryFilter = .all
                } label: {
                    Label("All Categories", systemImage: "tray.full.fill")
                }

                Divider()

                // Each item category
                ForEach(VaultCategory.itemCategories) { cat in
                    Button {
                        listCategoryFilter = cat
                    } label: {
                        Label(cat.rawValue, systemImage: cat.primarySymbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    // Category icon
                    if listCategoryFilter == .all {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.fpAccentBlue)
                    } else {
                        CategoryIcon(listCategoryFilter, size: 22)
                    }

                    Text(listCategoryFilter == .all ? "All Categories" : listCategoryFilter.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.fpTextPrimary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.fpTextSecondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.fpSurfaceHover.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Item count
            Text("\(filteredItems.count) items")
                .font(.system(size: 12))
                .foregroundColor(.fpTextSecondary)
        }
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        ZStack(alignment: .top) {
            Color.fpDetail.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Integrated Title Bar Area
                HStack { Spacer() }
                    .frame(height: titleBarHeight)
                    .padding(.top, 4)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: contentTopPadding)

                        if let item = selectedItem {
                            VaultDetailView(item: item, onDelete: {
                                selectedItem = nil
                                deleteItem(item)
                            })
                        } else {
                            VStack(spacing: 12) {
                                Image("VaultEmptyState")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 400, maxHeight: 400)
                                    .opacity(0.8)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                Text("Select an item to view details")
                                    .font(.title3)
                                    .foregroundColor(.fpTextSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                        
                        Spacer(minLength: 40)
                    }
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
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : iconColor)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .fpTextPrimary)
            
            Spacer()
            
            if let c = count, c > 0 {
                Text("\(c)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? .fpSelection : .white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white : Color(white: 0.3))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.fpSelection : (isHovering ? Color(white: 0.15) : Color.clear))
        .cornerRadius(8)
        .padding(.horizontal, 8)
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
            FaviconView(urlString: item.url, category: resolvedCategory, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .fpTextPrimary)
                        .lineLimit(1)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                    }
                }
                Text(item.username)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .fpTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.fpSelection : (isHovering ? Color.fpSurfaceHover : Color.clear))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onHover { hover in isHovering = hover }
    }
}

// MARK: - Category Selection Grid remains unchanged...
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
    let mainColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let otherColumns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Color(white: 0.1), Color(white: 0.15)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Text("What would you like to add?").font(.system(size: 22, weight: .bold)).foregroundColor(.white).padding(.top, 40)
                    TextField("", text: $searchText, prompt: Text("Search categories").foregroundColor(.gray))
                        .padding(10).background(Color.white.opacity(0.1)).cornerRadius(8).padding(20)
                    if !filteredMain.isEmpty {
                        LazyVGrid(columns: mainColumns, spacing: 12) {
                            ForEach(filteredMain) { category in
                                MainCategoryCard(category: category).onTapGesture { dismiss(); onSelect(category) }
                            }
                        }.padding(.horizontal, 20)
                    }
                    if !filteredOther.isEmpty {
                        LazyVGrid(columns: otherColumns, spacing: 12) {
                            ForEach(filteredOther) { category in
                                OtherCategoryCard(category: category).onTapGesture { dismiss(); onSelect(category) }
                            }
                        }.padding(.horizontal, 20).padding(.top, 20)
                    }
                }
            }
            Button { dismiss() } label: { Text("×").font(.title).foregroundColor(.white).padding() }.buttonStyle(.plain)
        }.frame(width: 500, height: 600)
    }
}
struct MainCategoryCard: View {
    let category: VaultCategory
    var body: some View {
        VStack {
            CategoryIcon(category, size: 40)
            Text(category.rawValue).font(.caption).foregroundColor(.white)
        }.padding().background(Color.white.opacity(0.1)).cornerRadius(10)
    }
}
struct OtherCategoryCard: View {
    let category: VaultCategory
    var body: some View {
        HStack {
            CategoryIcon(category, size: 24)
            Text(category.rawValue).font(.caption).foregroundColor(.white)
            Spacer()
        }.padding().background(Color.white.opacity(0.1)).cornerRadius(10)
    }
}
