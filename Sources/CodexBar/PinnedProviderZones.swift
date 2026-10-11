import CodexBarCore
import SwiftUI
import UniformTypeIdentifiers

/// Pinned providers (top, up to `limit`) and the remaining tabs (below), arranged by dragging between and
/// within the two zones. Pinned providers are the Overview tab's rows and the stacked-bars rows, top to
/// bottom; tab order is the pinned providers first, then the rest.
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

    /// Pinned keeps its saved order; the rest follow the enabled order. Without a saved pin, the first
    /// enabled providers are pinned so the Overview and bars start populated.
    static func resolve(pinned saved: [UsageProvider], enabled: [UsageProvider], limit: Int) -> Self {
        var pinned = Array(saved.filter { enabled.contains($0) }.prefix(limit))
        if pinned.isEmpty {
            pinned = Array(enabled.prefix(limit))
        }
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
    /// The saved pin list, shared with the stacked-bars rows.
    func providerZones(enabled: [UsageProvider], limit: Int) -> ProviderZones {
        ProviderZones.resolve(pinned: self.stackedBarsProviders, enabled: enabled, limit: limit)
    }

    /// Saves pinned providers as both the stacked-bars rows and the Overview selection, and reorders the
    /// enabled providers as pinned-then-others while disabled providers keep their slots.
    func applyProviderZones(_ zones: ProviderZones, enabled: [UsageProvider]) {
        self.stackedBarsProviders = zones.pinned
        let order = self.orderedProviders()
        var queue = zones.tabOrder.map(\.instanceID)
        let enabledIDs = Set(enabled.map(\.instanceID))
        let reordered = order.map { id -> ProviderInstanceID in
            guard enabledIDs.contains(id), !queue.isEmpty else { return id }
            return queue.removeFirst()
        }
        if reordered != order {
            self.setProviderOrder(reordered)
        }
        for provider in enabled where !zones.pinned.contains(provider) {
            _ = self.setMergedOverviewProviderSelection(provider: provider, isSelected: false, activeProviders: enabled)
        }
        for provider in zones.pinned {
            _ = self.setMergedOverviewProviderSelection(provider: provider, isSelected: true, activeProviders: enabled)
        }
    }
}

@MainActor
struct PinnedProviderZonesView: View {
    @Bindable var settings: SettingsStore
    let enabled: [UsageProvider]
    let limit: Int
    @State private var draggedProvider: UsageProvider?

    private var zones: ProviderZones {
        self.settings.providerZones(enabled: self.enabled, limit: self.limit)
    }

    var body: some View {
        let zones = self.zones
        SettingsRowLabel(
            L("provider_zones_pinned_title"),
            subtitle: L("provider_zones_pinned_subtitle", String(self.limit)))
            .onAppear { self.syncIfNeeded() }
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

    /// Earlier builds kept the Overview selection, bar rows, and tab order apart; align them once so the
    /// list matches the menu.
    private func syncIfNeeded() {
        let zones = self.zones
        let overview = self.settings.resolvedMergedOverviewProviders(
            activeProviders: self.enabled,
            maxVisibleProviders: self.limit)
        guard Set(overview) != Set(zones.pinned) || self.enabled != zones.tabOrder else { return }
        self.settings.applyProviderZones(zones, enabled: self.enabled)
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
                if zone == .pinned, let index = zones.pinned.firstIndex(of: provider) {
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
                    self.settings.applyProviderZones(moved, enabled: self.enabled)
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
