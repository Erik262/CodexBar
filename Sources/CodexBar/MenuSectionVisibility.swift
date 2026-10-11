import CodexBarCore
import Foundation

/// Optional menu content a user can hide per provider. Persistence keys off the raw values.
enum MenuSectionToggle: String, CaseIterable, Identifiable, Sendable {
    case todayCost
    case latestTokens
    case currentWindow
    case costChart
    case costDetails
    case recentWindows
    case planUsage
    case accountActions
    case buyCredits
    case dashboardLink
    case statusPageLink
    case changelogLink

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .todayCost: L("menu_section_today_cost")
        case .latestTokens: L("menu_section_latest_tokens")
        case .currentWindow: L("menu_section_current_window")
        case .costChart: L("menu_section_cost_chart")
        case .costDetails: L("menu_section_cost_details")
        case .recentWindows: L("Recent windows")
        case .planUsage: L("Plan Usage")
        case .accountActions: L("menu_section_account_actions")
        case .buyCredits: L("Buy Credits")
        case .dashboardLink: L("Usage Dashboard")
        case .statusPageLink: L("Status Page")
        case .changelogLink: L("Changelog")
        }
    }

    /// Provider-specific by design: only Codex offers Buy Credits in its menu.
    private static let buyCreditsProviders: Set<UsageProvider> = [.codex]

    /// Whether `provider`'s menu can show this section at all; Settings hides toggles that would do nothing.
    func applies(to provider: UsageProvider) -> Bool {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
        switch self {
        case .todayCost, .latestTokens, .currentWindow, .costChart, .costDetails, .recentWindows:
            return descriptor.tokenCost.supportsTokenCost
        case .planUsage, .accountActions:
            return true
        case .buyCredits:
            return Self.buyCreditsProviders.contains(provider)
        case .dashboardLink:
            return descriptor.metadata.dashboardURL != nil
        case .statusPageLink:
            return descriptor.metadata.statusPageURL != nil || descriptor.metadata.statusLinkURL != nil
        case .changelogLink:
            return descriptor.metadata.changelogURL != nil
        }
    }
}

extension SettingsStore {
    /// Sections hidden for `provider`. Providers without their own choice fall back to the
    /// app-wide set saved before visibility became per provider.
    func hiddenMenuSections(for provider: UsageProvider) -> Set<MenuSectionToggle> {
        let raw = self.hiddenMenuSectionsByProviderRaw[provider.rawValue] ?? self.hiddenMenuSectionsRaw
        return Set(raw.compactMap(MenuSectionToggle.init(rawValue:)))
    }

    func isMenuSectionVisible(_ section: MenuSectionToggle, for provider: UsageProvider) -> Bool {
        !self.hiddenMenuSections(for: provider).contains(section)
    }

    func setMenuSection(_ section: MenuSectionToggle, visible: Bool, for provider: UsageProvider) {
        var hidden = self.hiddenMenuSections(for: provider)
        if visible {
            hidden.remove(section)
        } else {
            hidden.insert(section)
        }
        var byProvider = self.hiddenMenuSectionsByProviderRaw
        byProvider[provider.rawValue] = hidden.map(\.rawValue).sorted()
        self.hiddenMenuSectionsByProviderRaw = byProvider
    }
}

/// How a provider's menu shows its service status: not at all, as the Status Page link, or as the
/// compact component list. Inline falls back to the link until the status page has published components.
enum StatusPagePresentation: String, CaseIterable, Identifiable, Sendable {
    case off
    case link
    case inline

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .off: L("status_page_off")
        case .link: L("status_page_link")
        case .inline: L("status_page_inline")
        }
    }

    /// Only statuspage.io-style feeds (`statusPageURL`) publish the component list the inline card needs.
    static func options(for provider: UsageProvider) -> [StatusPagePresentation] {
        let metadata = ProviderDescriptorRegistry.descriptor(for: provider).metadata
        return metadata.statusPageURL != nil ? [.off, .link, .inline] : [.off, .link]
    }
}

extension SettingsStore {
    func statusPagePresentation(for provider: UsageProvider) -> StatusPagePresentation {
        guard self.isMenuSectionVisible(.statusPageLink, for: provider) else { return .off }
        let inline = self.statusInlineByProviderRaw[provider.rawValue] ?? self.statusComponentsInline
        return inline ? .inline : .link
    }

    func setStatusPagePresentation(_ presentation: StatusPagePresentation, for provider: UsageProvider) {
        self.setMenuSection(.statusPageLink, visible: presentation != .off, for: provider)
        guard presentation != .off else { return }
        var byProvider = self.statusInlineByProviderRaw
        byProvider[provider.rawValue] = presentation == .inline
        self.statusInlineByProviderRaw = byProvider
    }
}
