import Foundation
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
    func `indexed entries are unique per pane`() {
        let ids = SettingsSearchIndex.entries.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test
    func `search matches settings by title words in any order`() {
        let results = SettingsSearchIndex.matches("login start").map(\.titleKey)
        #expect(results == ["start_at_login_title"])
        #expect(SettingsSearchIndex.matches("REFRESH").contains { $0.pane == .general })
        #expect(SettingsSearchIndex.matches("   ").isEmpty)
        #expect(SettingsSearchIndex.matches("zzzz-no-such-setting").isEmpty)
    }

    @Test
    func `a chosen result stays fresh briefly for the pane it opens`() {
        let focus = SettingsSearchFocus()
        focus.focus(title: "Start at Login")
        #expect(focus.isFresh(for: "Start at Login"))
        #expect(!focus.isFresh(for: "Other"))
        #expect(!focus.isFresh(for: "Start at Login", now: Date().addingTimeInterval(5)))
    }

    @Test
    func `pane titles match case and diacritic insensitively`() {
        #expect(SettingsSearchIndex.text(SettingsPane.notifications.title, matches: "NOTIF"))
        #expect(SettingsSearchIndex.text("Café", matches: "cafe"))
        #expect(!SettingsSearchIndex.text(SettingsPane.notifications.title, matches: "zzz"))
    }
}
