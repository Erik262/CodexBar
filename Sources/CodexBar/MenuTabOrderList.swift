import CodexBarCore
import SwiftUI
import UniformTypeIdentifiers

/// The provider tabs of the merged menu in one list: the checkbox puts a provider on the Overview tab
/// (up to `overviewLimit`), dragging sets the tab order. Tabs follow the global provider order, so
/// reordering here also reorders the Settings sidebar's custom order.
@MainActor
struct MenuTabOrderList: View {
    @Bindable var settings: SettingsStore
    let providers: [UsageProvider]
    let overviewLimit: Int
    let isOnOverview: (UsageProvider) -> Bool
    let setOnOverview: (UsageProvider, Bool) -> Void
    @State private var draggedProvider: UsageProvider?

    var body: some View {
        SettingsRowLabel(
            L("menu_tab_order_title"),
            subtitle: L("menu_tab_order_overview_subtitle", String(self.overviewLimit)))
        ForEach(self.providers, id: \.self) { provider in
            HStack(spacing: 8) {
                let selectedCount = self.providers.count(where: self.isOnOverview)
                Toggle(isOn: Binding(
                    get: { self.isOnOverview(provider) },
                    set: { self.setOnOverview(provider, $0) }))
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
                .disabled(!self.isOnOverview(provider) && selectedCount >= self.overviewLimit)
                Spacer(minLength: 0)
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .onDrag {
                self.draggedProvider = provider
                return NSItemProvider(object: provider.rawValue as NSString)
            }
            .onDrop(
                of: [UTType.plainText],
                delegate: MenuTabOrderDropDelegate(
                    target: provider,
                    dragged: self.$draggedProvider,
                    move: { self.settings.moveProvider($0, onto: $1) }))
        }
    }
}

/// Moves the dragged tab live while hovering and reports a move so macOS shows no "+" badge.
@MainActor
private struct MenuTabOrderDropDelegate: @preconcurrency DropDelegate {
    let target: UsageProvider
    @Binding var dragged: UsageProvider?
    let move: (UsageProvider, UsageProvider) -> Void

    func dropEntered(info _: DropInfo) {
        guard let dragged, dragged != self.target else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            self.move(dragged, self.target)
        }
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        self.dragged = nil
        return true
    }
}

extension SettingsStore {
    /// Moves `provider` next to `target` in the global order: below it when moving down, above it when moving up.
    func moveProvider(_ provider: UsageProvider, onto target: UsageProvider) {
        let order = self.orderedProviders()
        guard let reordered = Self.reorderedProviders(order, moving: provider.instanceID, onto: target.instanceID)
        else { return }
        self.setProviderOrder(reordered)
    }

    nonisolated static func reorderedProviders(
        _ order: [ProviderInstanceID],
        moving dragged: ProviderInstanceID,
        onto target: ProviderInstanceID) -> [ProviderInstanceID]?
    {
        guard dragged != target,
              let fromIndex = order.firstIndex(of: dragged),
              let originalTargetIndex = order.firstIndex(of: target)
        else { return nil }
        var result = order
        result.remove(at: fromIndex)
        guard let targetIndex = result.firstIndex(of: target) else { return nil }
        result.insert(dragged, at: fromIndex < originalTargetIndex ? targetIndex + 1 : targetIndex)
        return result
    }
}
