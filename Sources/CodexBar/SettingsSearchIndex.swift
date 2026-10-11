import Foundation

/// Searchable settings rows for the sidebar search field. Each entry names the localization key of a
/// visible row title (or section header) and the pane that shows it; selecting a result opens that pane.
struct SettingsSearchEntry: Identifiable, Hashable {
    let titleKey: String
    let pane: SettingsPane

    var id: String {
        "\(self.pane.persistenceToken)|\(self.titleKey)"
    }

    var title: String {
        L(self.titleKey)
    }
}

enum SettingsSearchIndex {
    /// Row titles per pane, in on-screen order. Keep in sync when adding a setting a user might look for.
    static var titleKeysByPane: [(pane: SettingsPane, keys: [String])] {
        [
            (.general, [
                "language_title",
                "currency_title",
                "terminal_app_title",
                "start_at_login_title",
                "refresh_interval_title",
                "refresh_on_open_title",
                "Low Power Mode",
                "check_provider_status_title",
                "open_menu_shortcut_title",
            ]),
            (.iCloudSync, [
                "Sync settings and providers across your Macs via iCloud",
                "Include API keys, cookies, and tokens",
                "Sync usage snapshots",
                "Show accounts from other Macs",
            ]),
            (.notifications, [
                "credential_expiry_notifications_title",
                "quota_depleted_title",
                "threshold_warnings_title",
                "predictive_pace_warnings_title",
                "limit_reset_notifications_title",
                "confetti_on_reset_title",
            ]),
            (.menuBar, [
                "menu_bar_style_title",
                "menu_bar_inactive_display_contrast_title",
                "Color Pace Indicator",
                "Pace sign",
                "Color by provider",
                "menu_bar_status_badge_title",
                "menu_bar_layout_title",
                "merge_icons_title",
                "merged_icon_style_title",
                "stacked_bars_window_title",
                "stacked_bars_show_icons_title",
                "stacked_bars_rows_title",
                "switcher_rows_title",
                "overview_tab_providers_title",
                "surprise_me_title",
            ]),
            (.menu, [
                "usage_bars_fill_title",
                "show_quota_warning_markers_title",
                "show_pace_title",
                "weekly_progress_work_days_title",
                "workday_tick_appearance_title",
                "reset_times_title",
                "show_provider_changelog_links_title",
                "overview_layout_title",
                "show_credits_extra_usage_title",
                "multi_account_layout_title",
                "menu_card_hover_highlight_title",
                "status_components_inline_title",
                "app_actions_overview_only_title",
                "account_widgets_title",
                "cost_summary_title",
                "cost_history_window_title",
                "cost_comparison_periods_title",
                "Stay Awake",
                "agent_sessions_title",
            ]),
            (.advanced, [
                "install_cli",
                "hide_personal_info_title",
                "disable_keychain_access_title",
                "show_provider_storage_usage_title",
                "show_debug_settings_title",
            ]),
            (.hooks, ["hooks_enable_title"]),
            (.plugins, ["Install plugin"]),
        ]
    }

    static var entries: [SettingsSearchEntry] {
        self.titleKeysByPane.flatMap { group in
            group.keys.map { SettingsSearchEntry(titleKey: $0, pane: group.pane) }
        }
    }

    /// Case- and diacritic-insensitive match on the localized title; every word must match, in any order.
    static func matches(_ query: String, in entries: [SettingsSearchEntry] = Self.entries) -> [SettingsSearchEntry] {
        entries.filter { self.text($0.title, matches: query) }
    }

    static func text(_ text: String, matches query: String) -> Bool {
        let words = query
            .split(whereSeparator: \.isWhitespace)
            .map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
        guard !words.isEmpty else { return false }
        let haystack = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return words.allSatisfy { haystack.contains($0) }
    }
}
