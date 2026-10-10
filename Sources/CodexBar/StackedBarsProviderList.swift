import CodexBarCore
import SwiftUI

/// Rows of the stacked-bars icon. Checked providers render top to bottom; drag a row to reorder.
@MainActor
struct StackedBarsProviderList: View {
    @Bindable var settings: SettingsStore
    let eligibleProviders: [UsageProvider]
    let activeRows: [UsageProvider]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsRowLabel(L("stacked_bars_rows_title"), subtitle: L("stacked_bars_rows_subtitle"))
            ForEach(Self.ordered(rows: self.activeRows, eligible: self.eligibleProviders), id: \.self) { provider in
                self.row(provider)
                    .draggable(provider.rawValue)
                    .dropDestination(for: String.self) { items, _ in
                        guard let raw = items.first, let dragged = UsageProvider(rawValue: raw) else { return false }
                        self.settings.stackedBarsProviders = Self.reordered(
                            rows: self.activeRows,
                            moving: dragged,
                            onto: provider)
                        return true
                    }
            }
        }
    }

    private func row(_ provider: UsageProvider) -> some View {
        let isSelected = self.activeRows.contains(provider)
        return HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            if let icon = ProviderBrandIcon.image(for: provider) {
                Image(nsImage: icon)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
            }
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { self.setSelected(provider, selected: $0) }))
            {
                Text(ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName)
            }
            .toggleStyle(.checkbox)
            .disabled(isSelected
                ? self.activeRows.count <= 2
                : self.activeRows.count >= StackedBarsIconRenderer.maxRows)
            Spacer(minLength: 0)
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
