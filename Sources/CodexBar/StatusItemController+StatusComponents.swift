import AppKit
import CodexBarCore

extension StatusItemController {
    /// Rows that replace the plain action item: the persistent Refresh row and the inline status card.
    func customActionMenuItem(
        _ action: MenuDescriptor.MenuAction,
        title: String,
        menu: NSMenu,
        provider: UsageProvider?,
        width: CGFloat) -> NSMenuItem?
    {
        if action == .refresh {
            let item = self.makePersistentRefreshItem(title: L(title), menu: menu, width: width)
            self.persistentRefreshItems.add(item)
            return item
        }
        guard action == .statusPage, let provider else { return nil }
        return self.makeInlineStatusComponentsItem(provider: provider, width: width)
    }

    /// Providers that surface the live component list as a native submenu. Every other provider
    /// keeps the plain "Status Page" link that opens the website. Kept deliberately small: these
    /// are the statuspage.io/incident.io feeds we actively curate and trust to render well.
    /// Provider-specific by design: these four curated status feeds expose component trees rendered by the app.
    static let statusComponentsSubmenuProviders: Set<UsageProvider> = [.claude, .codex, .augment, .zoommate]

    /// Filters `components` down to a provider's descriptor-owned named allowlist, if configured;
    /// returns `components` unchanged when the provider has no allowlist. Matching is by exact
    /// `name` equality at the top level only (groups and leaves alike).
    static func filterStatusComponents(
        _ components: [ProviderStatusComponent],
        for provider: UsageProvider) -> [ProviderStatusComponent]
    {
        let metadata = ProviderDescriptorRegistry.descriptor(for: provider).metadata
        guard let allowlist = metadata.statusComponentAllowlist else { return components }
        return components.filter { allowlist.contains($0.name) }
    }

    /// Builds the status submenu (component rows + a website link) for the curated providers in
    /// `statusComponentsSubmenuProviders`. Gated on the provider being in that allowlist (and
    /// having a component feed) rather than on components being loaded yet: status is fetched
    /// asynchronously, so gating on loaded components would leave the row as a plain link for any
    /// provider whose first fetch hasn't landed at menu-build time. The submenu hydrates from the
    /// live component list each time it opens (and shows just the website link until the first
    /// fetch lands). Returns nil for all other providers, which keep the plain status-page link.
    /// For curated providers, turns the "Status Page" row into a submenu of live component
    /// statuses instead of a direct website link (the link moves to the bottom of the submenu).
    func attachStatusComponentsSubmenuIfNeeded(
        to item: NSMenuItem,
        action: MenuDescriptor.MenuAction,
        provider: UsageProvider?,
        width: CGFloat)
    {
        guard action == .statusPage,
              let provider,
              let submenu = self.makeStatusComponentsSubmenu(provider: provider, width: width)
        else { return }
        item.action = nil
        item.submenu = submenu
    }

    /// Components for the inline status card: any provider whose status page published a component list,
    /// once the user opted in. Empty keeps the regular Status Page row and its summary line.
    static func inlineStatusComponents(store: UsageStore, provider: UsageProvider) -> [ProviderStatusComponent] {
        guard store.settings.statusPagePresentation(for: provider) == .inline else { return [] }
        return self.filterStatusComponents(store.statusComponents(for: provider), for: provider)
    }

    /// The compact status card that replaces the Status Page submenu when the user opted in and
    /// components have loaded; nil keeps the regular row.
    func makeInlineStatusComponentsItem(provider: UsageProvider, width: CGFloat) -> NSMenuItem? {
        let components = Self.inlineStatusComponents(store: self.store, provider: provider)
        guard !components.isEmpty else { return nil }
        let metadata = self.store.metadata(for: provider)
        let url = (metadata.statusPageURL ?? metadata.statusLinkURL).flatMap(URL.init(string:))
        let onClick: (() -> Void)? = url.map { url in { _ = NSWorkspace.shared.open(url) } }
        let item = self.makeMenuCardItem(
            CompactStatusComponentsView(components: components),
            id: Self.statusComponentsID + "Inline",
            width: width,
            heightCacheScope: provider.rawValue,
            heightCacheFingerprint: "statusInline:\(components.count)",
            onClick: onClick)
        item.title = L("Status Page")
        return item
    }

    func makeStatusComponentsSubmenu(provider: UsageProvider, width: CGFloat? = nil) -> NSMenu? {
        guard self.store.statusChecksEnabled else { return nil }
        guard Self.statusComponentsSubmenuProviders.contains(provider) else { return nil }
        guard ProviderDescriptorRegistry.descriptor(for: provider).metadata.statusPageURL != nil else { return nil }
        if let width {
            return self.makeHostedSubviewPlaceholderMenu(
                chartID: Self.statusComponentsID,
                provider: provider,
                width: width)
        }
        return self.makeHostedSubviewPlaceholderMenu(chartID: Self.statusComponentsID, provider: provider)
    }
}
