import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct SettingsPersistenceContractTests {
    @Test
    func `older clients sorting changes remain authoritative on restart`() {
        let defaults = InMemoryUserDefaults()
        defaults.set("custom", forKey: "providerListSortMode")
        defaults.set(true, forKey: "providersSortedAlphabetically")
        #expect(testSettingsStore(suiteName: #function, userDefaults: defaults).providersSortedAlphabetically)
        defaults.set("alphabetical", forKey: "providerListSortMode")
        defaults.set(false, forKey: "providersSortedAlphabetically")
        #expect(!testSettingsStore(suiteName: #function, userDefaults: defaults).providersSortedAlphabetically)
    }

    @Test
    func `portable export preserves older clients sorting changes`() throws {
        for (raw, alphabetical) in [("custom", true), ("alphabetical", false)] {
            let defaults = InMemoryUserDefaults()
            defaults.set(raw, forKey: "providerListSortMode")
            defaults.set(alphabetical, forKey: "providersSortedAlphabetically")
            let exported = try PreferencesDocument(data: PreferencesDocument(defaults: defaults).encoded())
            #expect(try exported.value("providersSortedAlphabetically", as: Bool.self) == alphabetical)
            #expect(try exported.value("providerListSortMode", as: String.self) == nil)
        }
    }

    @Test
    func `menu hover highlighting defaults on and persists both choices`() {
        let defaults = InMemoryUserDefaults()
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(settings.highlightMenuCardsOnHover)
        settings.highlightMenuCardsOnHover = false
        let reloaded = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(!reloaded.highlightMenuCardsOnHover)
        reloaded.highlightMenuCardsOnHover = true
        #expect(testSettingsStore(suiteName: #function, userDefaults: defaults).highlightMenuCardsOnHover)
    }

    @Test
    func `menu hover highlighting keeps the earlier fork choice`() {
        let defaults = InMemoryUserDefaults(values: ["menuCardHoverHighlightEnabled": false])
        #expect(!testSettingsStore(suiteName: #function, userDefaults: defaults).highlightMenuCardsOnHover)
    }

    @Test
    func `optional and raw preferences round trip without boxed nil values`() {
        let defaults = InMemoryUserDefaults()
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        settings.weeklyProgressWorkDays = 4
        settings.mergeIconStackedTopProviderRaw = "claude"
        settings.menuBarDisplayMode = .pace
        settings.iCloudSyncDeviceID = "synthetic-device"
        settings.iCloudSyncSnapshotsEnabled = false

        let reloaded = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(reloaded.weeklyProgressWorkDays == 4)
        #expect(reloaded.mergeIconStackedTopProviderRaw == "claude")
        #expect(reloaded.menuBarDisplayMode == .pace)
        #expect(reloaded.iCloudSyncDeviceID == "synthetic-device")
        #expect(!reloaded.iCloudSyncSnapshotsEnabled)
        #expect(defaults.string(forKey: "menuBarDisplayMode") == MenuBarDisplayMode.pace.rawValue)
        #expect(defaults.object(forKey: "menuBarDisplayModeRaw") == nil)

        reloaded.weeklyProgressWorkDays = nil
        reloaded.mergeIconStackedTopProviderRaw = nil
        #expect(defaults.object(forKey: "weeklyProgressWorkDays") == nil)
        #expect(defaults.object(forKey: "mergeIconStackedTopProvider") == nil)
        let cleared = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(cleared.weeklyProgressWorkDays == nil)
        #expect(cleared.mergeIconStackedTopProviderRaw == nil)
    }

    @Test
    func `menu visibility toggles persist and default to visible`() {
        let defaults = InMemoryUserDefaults()
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(MenuSectionToggle.allCases.allSatisfy { settings.isMenuSectionVisible($0, for: .claude) })
        #expect(!settings.menuBarStatusBadgeVisible)
        #expect(!settings.appActionsOnOverviewOnly)
        #expect(!settings.statusComponentsInline)

        settings.setMenuSection(.todayCost, visible: false, for: .claude)
        settings.setMenuSection(.planUsage, visible: false, for: .claude)
        settings.setMenuSection(.accountActions, visible: false, for: .openai)
        settings.menuBarStatusBadgeVisible = true
        settings.appActionsOnOverviewOnly = true
        settings.statusComponentsInline = true

        let reloaded = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(reloaded.hiddenMenuSections(for: .claude) == [.todayCost, .planUsage])
        #expect(reloaded.hiddenMenuSections(for: .openai) == [.accountActions])
        #expect(reloaded.hiddenMenuSections(for: .codex).isEmpty)
        #expect(reloaded.menuBarStatusBadgeVisible)
        #expect(reloaded.appActionsOnOverviewOnly)
        #expect(reloaded.statusComponentsInline)

        reloaded.setMenuSection(.todayCost, visible: true, for: .claude)
        #expect(reloaded.hiddenMenuSections(for: .claude) == [.planUsage])
    }

    @Test
    func `status page presentation is chosen per provider and persists`() {
        let defaults = InMemoryUserDefaults(values: ["statusComponentsInline": true])
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        // The earlier app-wide switch is the default for providers without their own choice.
        #expect(settings.statusPagePresentation(for: .codex) == .inline)

        settings.setStatusPagePresentation(.link, for: .codex)
        settings.setStatusPagePresentation(.off, for: .claude)

        let reloaded = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(reloaded.statusPagePresentation(for: .codex) == .link)
        #expect(reloaded.statusPagePresentation(for: .claude) == .off)
        #expect(!reloaded.isMenuSectionVisible(.statusPageLink, for: .claude))
        #expect(reloaded.statusPagePresentation(for: .openai) == .inline)

        reloaded.setStatusPagePresentation(.inline, for: .claude)
        #expect(reloaded.statusPagePresentation(for: .claude) == .inline)
        #expect(StatusPagePresentation.options(for: .openai).contains(.inline))
    }

    @Test
    func `providers without their own visibility choice inherit the earlier app-wide set`() {
        let defaults = InMemoryUserDefaults(values: ["hiddenMenuSections": ["costChart", "todayCost"]])
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(settings.hiddenMenuSections(for: .codex) == [.costChart, .todayCost])

        settings.setMenuSection(.costChart, visible: true, for: .codex)
        #expect(settings.hiddenMenuSections(for: .codex) == [.todayCost])
        #expect(settings.hiddenMenuSections(for: .claude) == [.costChart, .todayCost])
    }

    @Test
    func `normalized cost assignments preserve revision and persistence semantics`() {
        let defaults = InMemoryUserDefaults()
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        let revision = settings.costUsageSettingsRevision
        settings.costUsageBucketTimeZoneIdentifier = " UTC "
        #expect(settings.costUsageSettingsRevision == revision + 1)
        #expect(defaults.string(forKey: "tokenCostUsageBucketTimeZone") == "UTC")
        settings.costUsageBucketTimeZoneIdentifier = "UTC"
        #expect(settings.costUsageSettingsRevision == revision + 1)
        settings.spendDashboardHiddenSourceIDs = ["b", "", "a", "b"]
        #expect(settings.spendDashboardHiddenSourceIDs == ["a", "b"])
        #expect(settings.costUsageSettingsRevision == revision + 2)
        settings.spendDashboardHiddenSourceIDs = ["b", "a"]
        #expect(settings.costUsageSettingsRevision == revision + 2)

        settings.hideNativeCodexCostWhenOpenCodexPresent = true
        #expect(settings.costUsageSettingsRevision == revision + 3)
        defaults.removeObject(forKey: "hideNativeCodexCostWhenOpenCodexPresent")
        settings.hideNativeCodexCostWhenOpenCodexPresent = true
        #expect(settings.costUsageSettingsRevision == revision + 3)
        #expect(defaults.bool(forKey: "hideNativeCodexCostWhenOpenCodexPresent"))

        let backgroundRevision = settings.backgroundWorkSettingsRevision
        settings.statusChecksEnabled = settings.statusChecksEnabled
        #expect(settings.backgroundWorkSettingsRevision == backgroundRevision + 1)
        settings.predictivePaceWarningNotificationsEnabled = settings.predictivePaceWarningNotificationsEnabled
        #expect(settings.backgroundWorkSettingsRevision == backgroundRevision + 1)
    }

    @Test
    func `default loading preserves false values and repairs malformed test defaults`() {
        let defaults = InMemoryUserDefaults(values: [
            "quotaWarningMarkersVisible": false,
            "paceVisible": "invalid",
            "providerStorageFootprintsEnabled": "invalid",
            "quotaWarningSessionEnabled": false,
            "quotaWarningWeeklyEnabled": "invalid",
            "quotaWarningOnScreenAlertEnabled": true,
        ])
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(!settings.quotaWarningMarkersVisible)
        #expect(settings.paceVisible)
        #expect(!settings.providerStorageFootprintsEnabled)
        #expect(!settings.quotaWarningWindowEnabled(.session))
        #expect(settings.quotaWarningWindowEnabled(.weekly))
        #expect(settings.quotaWarningOnScreenAlertEnabled)
        #expect(defaults.object(forKey: "paceVisible") as? Bool == true)
        #expect(defaults.object(forKey: "providerStorageFootprintsEnabled") as? Bool == false)
        #expect(defaults.object(forKey: "quotaWarningWeeklyEnabled") as? Bool == true)
    }
}
