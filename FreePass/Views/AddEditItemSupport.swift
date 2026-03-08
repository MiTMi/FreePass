import SwiftUI
import UniformTypeIdentifiers

// MARK: - Custom Field Model

struct CustomField: Identifiable, Codable {
    var id: UUID = UUID()
    var label: String = ""
    var value: String = ""
    var isSecure: Bool = false
}

// MARK: - Drop Delegate: Category field reorder

struct CategoryFieldDropDelegate: DropDelegate {
    let targetId: String
    @Binding var fieldOrder: [String]
    @Binding var draggedId: String?

    func performDrop(info: DropInfo) -> Bool { draggedId = nil; return true }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedId, dragged != targetId,
              let from = fieldOrder.firstIndex(of: dragged),
              let to   = fieldOrder.firstIndex(of: targetId) else { return }
        withAnimation { fieldOrder.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}

// MARK: - Drop Delegate: Custom field reorder

struct CustomFieldDropDelegate: DropDelegate {
    let targetId: UUID
    @Binding var fields: [CustomField]
    @Binding var draggedId: UUID?

    func performDrop(info: DropInfo) -> Bool { draggedId = nil; return true }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedId, dragged != targetId,
              let from = fields.firstIndex(where: { $0.id == dragged }),
              let to   = fields.firstIndex(where: { $0.id == targetId }) else { return }
        withAnimation { fields.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.map { $0.maxHeight }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for (subview, size) in row.items {
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }

    private struct Row {
        var items: [(LayoutSubview, CGSize)] = []
        var maxHeight: CGFloat { items.map { $0.1.height }.max() ?? 0 }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows.last!.items.isEmpty {
                rows.append(Row()); x = 0
            }
            rows[rows.count - 1].items.append((subview, size))
            x += size.width + spacing
        }
        return rows
    }
}
