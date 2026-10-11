import CodexBarCore
import SwiftUI
import UniformTypeIdentifiers

/// Rows of the stacked-bars icon. Checked providers render top to bottom; drag a row to reorder.
@MainActor
struct StackedBarsProviderList: View {
    @Bindable var settings: SettingsStore
    let eligibleProviders: [UsageProvider]
    let activeRows: [UsageProvider]
    @State private var draggedProvider: UsageProvider?

    var body: some View {
        SettingsRowLabel(L("stacked_bars_rows_title"), subtitle: L("stacked_bars_rows_subtitle"))
        ForEach(Self.ordered(rows: self.activeRows, eligible: self.eligibleProviders), id: \.self) { provider in
            self.row(provider)
                .onDrag {
                    self.draggedProvider = provider
                    return NSItemProvider(object: provider.rawValue as NSString)
                }
                .onDrop(
                    of: [UTType.plainText],
                    delegate: StackedBarsRowDropDelegate(
                        target: provider,
                        dragged: self.$draggedProvider,
                        rows: { self.activeRows },
                        apply: { self.settings.stackedBarsProviders = $0 }))
        }
    }

    private func row(_ provider: UsageProvider) -> some View {
        let isSelected = self.activeRows.contains(provider)
        return HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { self.setSelected(provider, selected: $0) }))
            {
                HStack(spacing: 6) {
                    if let icon = ProviderBrandIcon.image(for: provider) {
                        Image(nsImage: icon)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                    }
                    Text(ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(isSelected
                ? self.activeRows.count <= 2
                : self.activeRows.count >= StackedBarsIconRenderer.maxRows)
            Spacer(minLength: 0)
            if let index = self.activeRows.firstIndex(of: provider) {
                Text(String(format: L("stacked_bars_row_number"), index + 1))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    private func setSelected(_ provider: UsageProvider, selected: Bool) {
        var rows = self.activeRows
        if selected {
            rows.append(provider)
        } else {
            rows.removeAll { $0 == provider }
        }
        self.settings.stackedBarsProviders = rows
    }

    /// Selected rows first (in icon order), then the remaining enabled providers.
    nonisolated static func ordered(rows: [UsageProvider], eligible: [UsageProvider]) -> [UsageProvider] {
        rows + eligible.filter { !rows.contains($0) }
    }

    /// Drops `dragged` onto `target`: moving down lands below the target, moving up lands above it.
    /// Dropping an unselected provider onto a row selects it there; the list never exceeds the row limit.
    nonisolated static func reordered(
        rows: [UsageProvider],
        moving dragged: UsageProvider,
        onto target: UsageProvider) -> [UsageProvider]
    {
        guard dragged != target else { return rows }
        let fromIndex = rows.firstIndex(of: dragged)
        var result = rows.filter { $0 != dragged }
        guard let targetIndex = result.firstIndex(of: target) else {
            return fromIndex == nil ? rows : result + [dragged]
        }
        let movesDown = fromIndex.map { $0 <= targetIndex } ?? false
        result.insert(dragged, at: movesDown ? targetIndex + 1 : targetIndex)
        return Array(result.prefix(StackedBarsIconRenderer.maxRows))
    }
}

/// Reorders checked rows live while hovering and reports a move (not copy) so macOS shows no "+" badge.
@MainActor
private struct StackedBarsRowDropDelegate: @preconcurrency DropDelegate {
    let target: UsageProvider
    @Binding var dragged: UsageProvider?
    let rows: () -> [UsageProvider]
    let apply: ([UsageProvider]) -> Void

    func dropEntered(info _: DropInfo) {
        // Only reshuffle rows that are already in the icon; adding a provider waits for the drop.
        guard let dragged, dragged != self.target else { return }
        let rows = self.rows()
        guard rows.contains(dragged), rows.contains(self.target) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            self.apply(StackedBarsProviderList.reordered(rows: rows, moving: dragged, onto: self.target))
        }
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        defer { self.dragged = nil }
        guard let dragged else { return false }
        let rows = self.rows()
        let reordered = StackedBarsProviderList.reordered(rows: rows, moving: dragged, onto: self.target)
        if reordered != rows {
            self.apply(reordered)
        }
        return true
    }

    func dropExited(info _: DropInfo) {}
}
