import CodexBarCore
import SwiftUI

extension ProviderStatusIndicator {
    /// Traffic-light color used for the per-component dot in the status submenu.
    fileprivate var dotColor: Color {
        switch self {
        case .none: Color(red: 0.20, green: 0.78, blue: 0.35)
        case .minor, .maintenance: Color(red: 0.96, green: 0.77, blue: 0.13)
        case .major, .critical: Color(red: 0.91, green: 0.30, blue: 0.24)
        case .unknown: Color.secondary
        }
    }
}

/// Renders the list of statuspage.io component rows inside the provider's status submenu.
/// Each leaf row is: colored dot (far left) · service name · right-aligned status text.
/// A component group renders as an expandable dropdown: the parent shows the group's own
/// status, and a chevron reveals the individual child statuses indented beneath it
/// (modeled on the "Other" disclosure in StorageBreakdownMenuView).
struct StatusComponentsMenuView: View {
    let components: [ProviderStatusComponent]
    let width: CGFloat
    /// Invoked after a group expands or collapses so the host can re-measure the row height.
    let onToggle: (() -> Void)?

    @State private var expandedGroupIDs: Set<String> = []

    init(
        components: [ProviderStatusComponent],
        width: CGFloat,
        onToggle: (() -> Void)? = nil)
    {
        self.components = components
        self.width = width
        self.onToggle = onToggle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(self.components) { component in
                if component.isGroup {
                    self.groupRow(component)
                } else {
                    self.statusRow(component)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: self.width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .codexBarLocalized()
    }

    /// A single leaf row: dot · name · right-aligned status.
    private func statusRow(
        _ component: ProviderStatusComponent,
        indented: Bool = false,
        isExpanded: Bool? = nil) -> some View
    {
        HStack(spacing: 8) {
            Circle()
                .fill(component.indicator.dotColor)
                .frame(width: 8, height: 8)
            Text(component.name)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let isExpanded {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.16), value: isExpanded)
            }
            Spacer(minLength: 16)
            Text(component.statusLabel)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.leading, indented ? 17 : 0)
    }

    /// An expandable group: parent status row with a chevron, revealing children when expanded.
    private func groupRow(_ group: ProviderStatusComponent) -> some View {
        let isExpanded = self.expandedGroupIDs.contains(group.id)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                if isExpanded {
                    self.expandedGroupIDs.remove(group.id)
                } else {
                    self.expandedGroupIDs.insert(group.id)
                }
                self.onToggle?()
            } label: {
                self.statusRow(group, isExpanded: isExpanded)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.children) { child in
                        self.statusRow(child, indented: true)
                    }
                }
            }
        }
    }
}

/// Compact, always-visible status card used instead of the Status Page submenu: one dense row per
/// top-level component. Clicking the card opens the provider's status page.
struct CompactStatusComponentsView: View {
    let components: [ProviderStatusComponent]
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: MenuDescriptor.MenuActionSystemImage.statusPage.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .accessibilityHidden(true)
                Text(L("Status Page"))
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                    .accessibilityHidden(true)
            }
            ForEach(self.components) { component in
                HStack(spacing: 6) {
                    Circle()
                        .fill(component.indicator.dotColor)
                        .frame(width: 6, height: 6)
                    Text(component.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(component.statusLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                        .lineLimit(1)
                }
                .padding(.leading, 18)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .codexBarLocalized()
    }
}
