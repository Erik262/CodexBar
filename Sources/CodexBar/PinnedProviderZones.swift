import CodexBarCore
import SwiftUI
import UniformTypeIdentifiers

/// Pinned providers (top, up to `limit`) and the remaining tabs (below), arranged by dragging between and
/// within the two zones. Pinned providers are the Overview tab's rows, top to bottom, and the first
/// `StackedBarsIconRenderer.maxRows` of them are the stacked-bars rows; tab order is the pinned providers
/// first, then the rest.
struct ProviderZones: Equatable {
    enum Zone: Equatable {
        case pinned
        case others
    }

    var pinned: [UsageProvider]
    var others: [UsageProvider]

    var tabOrder: [UsageProvider] {
        self.pinned + self.others
    }

    /// Pinned mirrors the Overview selection in enabled order, so reading the zones never rewrites a saved
    /// selection; the rest follow the enabled order.
    static func resolve(overview: [ProviderInstanceID], enabled: [UsageProvider], limit: Int) -> Self {
        let selected = Set(overview)
        let pinned = Array(enabled.filter { selected.contains($0.instanceID) }.prefix(limit))
        return Self(pinned: pinned, others: enabled.filter { !pinned.contains($0) })
    }

    /// Moves `dragged` next to `target` in `zone` (onto the zone itself when `target` is nil). Returns nil
    /// when the drop would push the pinned zone past `limit`, so a full zone refuses new providers.
    func moving(_ dragged: UsageProvider, to zone: Zone, onto target: UsageProvider?, limit: Int) -> Self? {
        let wasPinned = self.pinned.contains(dragged)
        if zone == .pinned, !wasPinned, self.pinned.count >= limit { return nil }
        let sourceIndex = (wasPinned ? self.pinned : self.others).firstIndex(of: dragged)
        var result = Self(
            pinned: self.pinned.filter { $0 != dragged },
            others: self.others.filter { $0 != dragged })
        var list = zone == .pinned ? result.pinned : result.others
        if let target, target != dragged, let targetIndex = list.firstIndex(of: target) {
            // Within one zone, moving down lands below the target and moving up lands above it.
            let sameZone = wasPinned == (zone == .pinned)
            let movesDown = sameZone && (sourceIndex.map { $0 <= targetIndex } ?? false)
            list.insert(dragged, at: movesDown ? targetIndex + 1 : targetIndex)
        } else if target == dragged, let sourceIndex, wasPinned == (zone == .pinned) {
            list.insert(dragged, at: min(sourceIndex, list.count))
        } else {
            list.append(dragged)
        }
        if zone == .pinned {
            result.pinned = list
        } else {
            result.others = list
        }
        return result
    }
}

extension SettingsStore {
    /// Pins come from the Overview selection, which keeps its own unset/empty distinction and limit.
    func providerZones(
        enabled: [UsageProvider],
        allEnabled: [ProviderInstanceID],
        limit: Int) -> ProviderZones
    {
        let overview = self.resolvedMergedOverviewProviders(activeProviders: allEnabled, maxVisibleProviders: limit)
        return ProviderZones.resolve(overview: overview, enabled: enabled, limit: limit)
    }

    /// Saves a drag: pinned providers become the Overview selection (plugin selections are kept) and the
    /// stacked-bars rows, and enabled providers are reordered pinned-then-others while disabled providers
    /// keep their slots.
    func applyProviderZones(_ zones: ProviderZones, allEnabled: [ProviderInstanceID], limit: Int) {
        self.stackedBarsProviders = zones.pinned
        let order = self.orderedProviders()
        var queue = zones.tabOrder.map(\.instanceID)
        let movable = Set(queue)
        let reordered = order.map { id -> ProviderInstanceID in
            guard movable.contains(id), !queue.isEmpty else { return id }
            return queue.removeFirst()
        }
        if reordered != order {
            self.setProviderOrder(reordered)
        }
        let enabledIDs = Set(allEnabled)
        let active = reordered.filter { enabledIDs.contains($0) }
        let pinnedIDs = Set(zones.pinned.map(\.instanceID))
        for id in zones.tabOrder.map(\.instanceID) where !pinnedIDs.contains(id) {
            _ = self.setMergedOverviewProviderSelection(
                provider: id,
                isSelected: false,
                activeProviders: active,
                maxVisibleProviders: limit)
        }
        for provider in zones.pinned {
            _ = self.setMergedOverviewProviderSelection(
                provider: provider.instanceID,
                isSelected: true,
                activeProviders: active,
                maxVisibleProviders: limit)
        }
    }
}

@MainActor
struct PinnedProviderZonesView: View {
    @Bindable var settings: SettingsStore
    let enabled: [UsageProvider]
    let allEnabled: [ProviderInstanceID]
    let limit: Int
    @State private var draggedProvider: UsageProvider?

    private var zones: ProviderZones {
        self.settings.providerZones(enabled: self.enabled, allEnabled: self.allEnabled, limit: self.limit)
    }

    var body: some View {
        let zones = self.zones
        SettingsRowLabel(
            L("provider_zones_pinned_title"),
            subtitle: L("provider_zones_pinned_subtitle", String(self.limit)))
        self.rows(zones.pinned, zone: .pinned, zones: zones)
        if zones.pinned.isEmpty {
            self.placeholder(zone: .pinned, zones: zones)
        }

        SettingsRowLabel(L("provider_zones_others_title"), subtitle: L("provider_zones_others_subtitle"))
        self.rows(zones.others, zone: .others, zones: zones)
        if zones.others.isEmpty {
            self.placeholder(zone: .others, zones: zones)
        }
    }

    private func rows(_ providers: [UsageProvider], zone: ProviderZones.Zone, zones: ProviderZones) -> some View {
        ForEach(providers, id: \.self) { provider in
            HStack(spacing: 8) {
                if let icon = ProviderBrandIcon.image(for: provider) {
                    Image(nsImage: icon)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
                Text(ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName)
                Spacer(minLength: 0)
                if zone == .pinned, let index = zones.pinned.firstIndex(of: provider),
                   index < StackedBarsIconRenderer.maxRows
                {
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
            .onDrag {
                self.draggedProvider = provider
                return NSItemProvider(object: provider.rawValue as NSString)
            }
            .onDrop(of: [UTType.plainText], delegate: self.dropDelegate(zone: zone, target: provider, zones: zones))
        }
    }

    private func placeholder(zone: ProviderZones.Zone, zones: ProviderZones) -> some View {
        Text(L("provider_zones_drop_here"))
            .font(.callout)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 22)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.plainText], delegate: self.dropDelegate(zone: zone, target: nil, zones: zones))
    }

    private func dropDelegate(
        zone: ProviderZones.Zone,
        target: UsageProvider?,
        zones: ProviderZones) -> ProviderZoneDropDelegate
    {
        ProviderZoneDropDelegate(
            dragged: self.$draggedProvider,
            accepts: { dragged in zones.moving(dragged, to: zone, onto: target, limit: self.limit) != nil },
            perform: { dragged in
                guard let moved = zones.moving(dragged, to: zone, onto: target, limit: self.limit) else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.settings.applyProviderZones(moved, allEnabled: self.allEnabled, limit: self.limit)
                }
            })
    }
}

/// Reports a move (no "+" badge) for drops the zones accept and refuses drops into a full pinned zone.
@MainActor
private struct ProviderZoneDropDelegate: @preconcurrency DropDelegate {
    @Binding var dragged: UsageProvider?
    let accepts: (UsageProvider) -> Bool
    let perform: (UsageProvider) -> Void

    func validateDrop(info _: DropInfo) -> Bool {
        self.dragged.map(self.accepts) ?? false
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: self.dragged.map(self.accepts) == true ? .move : .forbidden)
    }

    func performDrop(info _: DropInfo) -> Bool {
        defer { self.dragged = nil }
        guard let dragged, self.accepts(dragged) else { return false }
        self.perform(dragged)
        return true
    }
}
