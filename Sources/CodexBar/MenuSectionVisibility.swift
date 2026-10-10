import Foundation

/// Optional menu content a user can hide. Persistence keys off the raw values.
enum MenuSectionToggle: String, CaseIterable, Identifiable, Sendable {
    case todayCost
    case costChart
    case recentWindows
    case accountActions
    case dashboardLink
    case statusPageLink

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .todayCost: L("menu_section_today_cost")
        case .costChart: L("menu_section_cost_chart")
        case .recentWindows: L("Recent windows")
        case .accountActions: L("menu_section_account_actions")
        case .dashboardLink: L("Usage Dashboard")
        case .statusPageLink: L("Status Page")
        }
    }
}

extension SettingsStore {
    var hiddenMenuSections: Set<MenuSectionToggle> {
        get { Set(self.hiddenMenuSectionsRaw.compactMap(MenuSectionToggle.init(rawValue:))) }
        set { self.hiddenMenuSectionsRaw = newValue.map(\.rawValue).sorted() }
    }

    func isMenuSectionVisible(_ section: MenuSectionToggle) -> Bool {
        !self.hiddenMenuSections.contains(section)
    }

    func setMenuSection(_ section: MenuSectionToggle, visible: Bool) {
        var hidden = self.hiddenMenuSections
        if visible {
            hidden.remove(section)
        } else {
            hidden.insert(section)
        }
        self.hiddenMenuSections = hidden
    }
}
