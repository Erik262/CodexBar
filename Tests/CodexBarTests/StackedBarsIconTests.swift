import AppKit
import CodexBarCore
import Testing
@testable import CodexBar

@MainActor
struct StackedBarsIconTests {
    @Test
    func `bars keep the user's order, drop disabled providers, and fill to two rows`() {
        let ordered = Self.presentation(providers: [.codex, .claude, .cursor], bars: [.cursor, .codex, .claude])
        #expect(ordered.effectiveStyle == .bars)
        #expect(ordered.barProviders == [.cursor, .codex, .claude])
        #expect(ordered.stackedProviders == nil)

        let stale = Self.presentation(providers: [.codex, .claude], bars: [.cursor])
        #expect(stale.barProviders == [.codex, .claude])

        let single = Self.presentation(providers: [.codex], bars: [.codex])
        #expect(single.barProviders == nil)
        #expect(single.effectiveStyle == .switcher)
    }

    @Test
    func `bars work with every menu bar icon style but need merged icons`() {
        let critters = Self.presentation(iconStyle: .critters)
        #expect(critters.barProviders == [.codex, .claude])

        let unmerged = Self.presentation(mergeIcons: false)
        #expect(unmerged.barProviders == nil)
    }

    @Test
    func `pinned zone mirrors the overview selection in enabled order`() {
        let enabled: [UsageProvider] = [.codex, .claude, .openai, .cursor]
        let zones = ProviderZones.resolve(
            overview: [UsageProvider.openai.instanceID, UsageProvider.codex.instanceID],
            enabled: enabled,
            limit: 6)
        #expect(zones.pinned == [.codex, .openai])
        #expect(zones.others == [.claude, .cursor])
        #expect(zones.tabOrder == [.codex, .openai, .claude, .cursor])
        #expect(ProviderZones.resolve(overview: [], enabled: enabled, limit: 6).pinned.isEmpty)
    }

    @Test
    func `reading pinned zones keeps a saved six provider overview and an empty selection`() {
        let settings = testSettingsStore(suiteName: #function, userDefaults: InMemoryUserDefaults())
        let enabled: [UsageProvider] = [.codex, .claude, .openai, .cursor, .gemini, .copilot, .zai]
        let ids = enabled.map(\.instanceID)
        let six = Array(ids.suffix(6))
        for id in ids {
            _ = settings.setMergedOverviewProviderSelection(
                provider: id,
                isSelected: six.contains(id),
                activeProviders: ids)
        }
        let zones = settings.providerZones(enabled: enabled, allEnabled: ids, limit: 6)
        #expect(zones.pinned == Array(enabled.suffix(6)))
        #expect(settings.resolvedMergedOverviewProviders(activeProviders: ids) == six)

        for id in six {
            _ = settings.setMergedOverviewProviderSelection(provider: id, isSelected: false, activeProviders: ids)
        }
        #expect(settings.providerZones(enabled: enabled, allEnabled: ids, limit: 6).pinned.isEmpty)
    }

    @Test
    func `stacked bars accessibility title reads each row`() {
        let title = StatusItemController.stackedBarsAccessibilityTitle(
            providers: [.codex, .claude],
            rows: [
                StackedBarsIconRenderer.Row(percent: 41.6, stale: false),
                StackedBarsIconRenderer.Row(percent: nil, stale: true),
            ])
        let codex = ProviderDescriptorRegistry.descriptor(for: .codex).metadata.displayName
        let claude = ProviderDescriptorRegistry.descriptor(for: .claude).metadata.displayName
        #expect(title == "\(codex) 42%, \(L("%@ unavailable", claude))")
    }

    @Test
    func `dragging between zones respects the pinned limit`() throws {
        let zones = ProviderZones(pinned: [.codex, .claude], others: [.openai, .cursor, .gemini])
        let added = try #require(zones.moving(.openai, to: .pinned, onto: .codex, limit: 3))
        #expect(added.pinned == [.openai, .codex, .claude])
        #expect(added.others == [.cursor, .gemini])
        #expect(added.moving(.cursor, to: .pinned, onto: .claude, limit: 3) == nil)

        let reordered = try #require(added.moving(.openai, to: .pinned, onto: .claude, limit: 3))
        #expect(reordered.pinned == [.codex, .claude, .openai])

        let unpinned = try #require(added.moving(.codex, to: .others, onto: nil, limit: 3))
        #expect(unpinned.pinned == [.openai, .claude])
        #expect(unpinned.others == [.cursor, .gemini, .codex])
    }

    @Test
    func `stacked bars style persists separately from the text stack`() {
        let defaults = InMemoryUserDefaults()
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        settings.mergedIconDisplayStyle = .bars
        settings.stackedBarsProviders = [.claude, .codex, .claude, .cursor, .gemini]
        settings.stackedBarsWindow = .weekly

        let reloaded = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(reloaded.mergedIconDisplayStyle == .bars)
        #expect(!reloaded.mergeIconsStacked)
        #expect(reloaded.stackedBarsProviders == [.claude, .codex, .cursor])
        #expect(reloaded.stackedBarsWindow == .weekly)

        reloaded.mergedIconDisplayStyle = .stacked
        #expect(!reloaded.mergeIconsStackedBars)
        #expect(reloaded.mergeIconsStacked)
    }

    @Test
    func `renderer sizes the canvas per row count and fills from the left`() throws {
        #expect(StackedBarsIconRenderer.Metrics(rowCount: 2).size.height == 18)
        #expect(StackedBarsIconRenderer.Metrics(rowCount: 3).size.height == 18)
        #expect(StackedBarsIconRenderer.Metrics(rowCount: 2).barHeight == 6)
        #expect(StackedBarsIconRenderer.Metrics(rowCount: 2, showsIcons: false).barX == 0)
        #expect(StackedBarsIconRenderer.makeImage(rows: [.init(percent: 50, stale: false)], icons: []).size.width
            == StackedBarsIconRenderer.barWidth)
        #expect(StackedBarsIconRenderer.fillWidth(percent: 50, barWidth: 28) == 14)
        #expect(StackedBarsIconRenderer.fillWidth(percent: nil, barWidth: 28) == 0)
        #expect(StackedBarsIconRenderer.fillWidth(percent: 140, barWidth: 28) == 28)

        let image = StackedBarsIconRenderer.makeImage(
            rows: [.init(percent: 100, stale: false), .init(percent: 0, stale: false)],
            icons: [nil, nil])
        #expect(image.isTemplate)
        #expect(image.size == StackedBarsIconRenderer.Metrics(rowCount: 2).size)

        let rep = try #require(image.representations.first as? NSBitmapImageRep)
        let metrics = StackedBarsIconRenderer.Metrics(rowCount: 2)
        let midX = Int((metrics.barX + StackedBarsIconRenderer.barWidth / 2) * 2)
        // Row 0 (top) is full, row 1 (bottom) is only the faint track.
        let topAlpha = try #require(rep.colorAt(x: midX, y: Int(metrics.rowHeight / 2 * 2))).alphaComponent
        let bottomAlpha = try #require(rep.colorAt(x: midX, y: Int(metrics.rowHeight * 1.5 * 2)))
            .alphaComponent
        #expect(topAlpha > 0.9)
        #expect(bottomAlpha < 0.5)
    }

    private static func presentation(
        providers: [UsageProvider] = [.codex, .claude],
        bars: [UsageProvider] = [],
        mergeIcons: Bool = true,
        iconStyle: MenuBarIconStyle = .iconAndPercent) -> MergedIconPresentation
    {
        MergedIconPresentation(
            mergeIcons: mergeIcons,
            iconStyle: iconStyle,
            requestedStyle: .bars,
            eligibleProviders: providers,
            preferredTop: nil,
            preferredBottom: nil,
            preferredBars: bars)
    }
}
