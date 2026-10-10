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
