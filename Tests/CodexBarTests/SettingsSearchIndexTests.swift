import CodexBarCore
import Testing
@testable import CodexBar

@MainActor
struct SettingsSearchIndexTests {
    @Test
    func `every indexed key resolves to a localized title`() {
        for entry in SettingsSearchIndex.entries where entry.titleKey.contains("_") {
            #expect(entry.title != entry.titleKey, "Missing English string for \(entry.titleKey)")
        }
    }

    @Test
    func `search matches settings by title words in any order`() {
        let results = SettingsSearchIndex.matches("icons provider show").map(\.titleKey)
        #expect(results.contains("stacked_bars_show_icons_title"))
        #expect(SettingsSearchIndex.matches("   ").isEmpty)
    }

    @Test
    func `pane titles match case insensitively`() {
        #expect(SettingsSearchIndex.text(SettingsPane.notifications.title, matches: "NOTIF"))
        #expect(!SettingsSearchIndex.text(SettingsPane.notifications.title, matches: "zzz"))
    }
}

@MainActor
struct MenuSectionToggleApplicabilityTests {
    @Test
    func `provider pages only offer sections the provider can show`() {
        #expect(MenuSectionToggle.buyCredits.applies(to: .codex))
        #expect(!MenuSectionToggle.buyCredits.applies(to: .claude))
        #expect(MenuSectionToggle.costChart.applies(to: .claude))
        #expect(!MenuSectionToggle.costChart.applies(to: .gemini))
        #expect(MenuSectionToggle.planUsage.applies(to: .gemini))
    }
}
