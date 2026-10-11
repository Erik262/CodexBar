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

struct MenuTabOrderTests {
    @Test
    func `dragging a tab lands below a later target and above an earlier one`() throws {
        let order = [UsageProvider.codex, .openai, .claude].map(\.instanceID)
        let down = try #require(SettingsStore.reorderedProviders(
            order, moving: UsageProvider.codex.instanceID, onto: UsageProvider.openai.instanceID))
        #expect(down == [UsageProvider.openai, .codex, .claude].map(\.instanceID))
        let up = try #require(SettingsStore.reorderedProviders(
            order, moving: UsageProvider.claude.instanceID, onto: UsageProvider.codex.instanceID))
        #expect(up == [UsageProvider.claude, .codex, .openai].map(\.instanceID))
        #expect(SettingsStore.reorderedProviders(
            order, moving: UsageProvider.codex.instanceID, onto: UsageProvider.codex.instanceID) == nil)
    }
}
