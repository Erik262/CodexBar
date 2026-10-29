import CodexBarCore
import SwiftUI

@MainActor
struct MenuBarPane: View {
    private static let maxOverviewProviders = SettingsStore.mergedOverviewProviderLimit

    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var isOverviewProviderPopoverPresented = false

    static func overviewProviderLimitText(limit: Int = Self.maxOverviewProviders) -> String {
        L("overview_choose_providers", String(limit))
    }

    static func layoutEditorEnabled(for style: MenuBarIconStyle) -> Bool {
        style == .iconAndPercent
    }

    static func layoutFooterText(for style: MenuBarIconStyle) -> String {
        self.layoutEditorEnabled(for: style)
            ? L("menu_bar_layout_footer")
            : L("menu_bar_layout_footer_requires_icon_and_percent", MenuBarIconStyle.iconAndPercent.label)
    }

    /// The merged style when icons are combined; nil while each provider has its own item.
    private var combinedStyle: MergedIconDisplayStyle? {
        self.settings.mergeIcons ? self.mergedIconPresentation.effectiveStyle : nil
    }

    /// Stacked bars draw their own image and Stacked text rows need Icon & percent, so the style picker
    /// only matters for separate items and the switcher.
    private var showsIconStylePicker: Bool {
        switch self.combinedStyle {
        case .bars?, .stacked?: false
        default: true
        }
    }

    private var showsPercentOptions: Bool {
        self.settings.menuBarIconStyle == .iconAndPercent && self.combinedStyle != .bars
    }

    var body: some View {
        Form {
            self.menuBarItemSection

            if self.combinedStyle == .bars {
                self.stackedBarsSection
            }

            if self.combinedStyle == .stacked, let pair = self.mergedIconPresentation.stackedProviders {
                self.stackedRowsSection(pair: pair)
            }

            if self.showsPercentOptions {
                self.percentSection
                self.layoutSection
            }

            self.appearanceSection

            self.menuTabsSection
        }
        .formStyle(.grouped)
        .settingsSearchScrollTarget()
        .toggleStyle(.switch)
        .scrollContentBackground(.hidden)
        .onAppear {
            self.reconcileOverviewSelection()
        }
        .onChange(of: self.settings.mergeIcons) { _, isEnabled in
            guard isEnabled else {
                self.isOverviewProviderPopoverPresented = false
                return
            }
            self.reconcileOverviewSelection()
        }
        .onChange(of: self.activeProvidersInOrder) { _, _ in
            if self.activeProvidersInOrder.isEmpty {
                self.isOverviewProviderPopoverPresented = false
            }
            self.reconcileOverviewSelection()
        }
    }

    /// The one decision everything else hangs off: separate items or one combined icon, then its style.
    private var menuBarItemSection: some View {
        Section {
            Toggle(isOn: self.$settings.mergeIcons) {
                SettingsRowLabel(L("merge_icons_title"), subtitle: L("merge_icons_subtitle"))
            }

            if self.settings.mergeIcons {
                SettingsMenuPicker(
                    selection: Binding(
                        get: { self.mergedIconPresentation.effectiveStyle },
                        set: { self.setCombinedStyle($0) }),
                    options: MenuBarSettingsMenuOptions.mergedIconStyles,
                    label: {
                        SettingsRowLabel(L("merged_icon_style_title"), subtitle: L("merged_icon_style_subtitle_all"))
                    },
                    optionLabel: { style in
                        Text(style.label)
                    })
                    .disabled(self.mergedIconPresentation.eligibleProviders.count < 2)
            }

            if self.showsIconStylePicker {
                SettingsMenuPicker(
                    selection: self.$settings.menuBarIconStyle,
                    options: MenuBarSettingsMenuOptions.iconStyles,
                    label: { Text(L("menu_bar_style_title")).settingsSearchAnchor(L("menu_bar_style_title")) },
                    optionLabel: { style in
                        Text(style.label)
                    })
            }
        } header: {
            Text(L("section_menu_bar_item"))
        }
    }

    private func setCombinedStyle(_ style: MergedIconDisplayStyle) {
        // Stacked text rows are built from Icon & percent layouts, so choosing them switches that style on
        // instead of silently falling back to the switcher.
        if style == .stacked {
            self.settings.menuBarIconStyle = .iconAndPercent
        }
        self.settings.mergedIconDisplayStyle = style
    }

    private var stackedBarsSection: some View {
        Section {
            self.stackedBarsSettings
        } header: {
            Text(L("merged_icon_style_bars"))
        } footer: {
            SettingsSectionFooter(L("stacked_bars_section_footer"))
        }
    }

    private func stackedRowsSection(pair: MergedIconPresentation.Pair) -> some View {
        Section {
            self.stackedRowProviderPicker(
                title: L("merge_icon_stacked_top_provider_title"),
                selection: Binding(
                    get: { self.mergedIconPresentation.topSelection },
                    set: { self.settings.mergeIconStackedTopProvider = $0 }),
                excluding: self.mergedIconPresentation.bottomSelection,
                automaticProvider: pair.top)
            self.stackedRowProviderPicker(
                title: L("merge_icon_stacked_bottom_provider_title"),
                selection: Binding(
                    get: { self.mergedIconPresentation.bottomSelection },
                    set: { self.settings.mergeIconStackedBottomProvider = $0 }),
                excluding: self.mergedIconPresentation.topSelection,
                automaticProvider: pair.bottom)
        } header: {
            Text(L("merged_icon_style_stacked"))
        }
    }

    private var percentSection: some View {
        Section {
            Toggle(isOn: self.$settings.menuBarHighContrastOnInactiveDisplays) {
                SettingsRowLabel(
                    L("menu_bar_inactive_display_contrast_title"),
                    subtitle: L("menu_bar_inactive_display_contrast_subtitle"))
            }

            Toggle(isOn: self.$settings.menuBarColorPace) {
                SettingsRowLabel(
                    L("Color Pace Indicator"),
                    subtitle: L(
                        "Green pace indicator when behind pace, red when ahead of pace " +
                            "(risk of running out early)"))
            }

            SettingsMenuPicker(
                selection: self.$settings.menuBarPaceReservePositive,
                options: [false, true],
                label: { Text(L("Pace sign")).settingsSearchAnchor(L("Pace sign")) },
                optionLabel: { reservePositive in
                    Text(reservePositive ? L("Reserve is +") : L("Ahead of pace is +"))
                })
        } header: {
            Text(L("menu_bar_style_icon_percent"))
        }
    }

    private var layoutSection: some View {
        Section {
            MenuBarLayoutEditor(settings: self.settings, store: self.store)
        } header: {
            Text(L("menu_bar_layout_title"))
        } footer: {
            SettingsSectionFooter(Self.layoutFooterText(for: self.settings.menuBarIconStyle))
        }
    }

    private var appearanceSection: some View {
        Section {
            Toggle(isOn: self.$settings.menuBarColorByProvider) {
                Text(L("Color by provider"))
            }

            Toggle(isOn: self.$settings.menuBarStatusBadgeVisible) {
                SettingsRowLabel(
                    L("menu_bar_status_badge_title"),
                    subtitle: L("menu_bar_status_badge_subtitle"))
            }

            // Brand icons and stacked bars never draw blink frames.
            if !self.settings.menuBarShowsBrandIconWithPercent, self.combinedStyle != .bars {
                Toggle(isOn: self.$settings.randomBlinkEnabled) {
                    SettingsRowLabel(L("surprise_me_title"), subtitle: L("surprise_me_subtitle"))
                }
            }
        } header: {
            Text(L("section_appearance"))
        }
    }

    @ViewBuilder
    private var menuTabsSection: some View {
        if self.settings.mergeIcons {
            Section {
                SettingsMenuPicker(
                    selection: self.$settings.switcherRowsOption,
                    options: MenuBarSettingsMenuOptions.switcherRows,
                    label: { SettingsRowLabel(L("switcher_rows_title")) },
                    optionLabel: { option in
                        Text(option.label)
                    })

                if self.mergedIconPresentation.effectiveStyle == .switcher {
                    UnifiedIconSourcePicker(selection: self.$settings.unifiedIconSource)
                }

                self.overviewProviderRow
                    .disabled(!self.settings.mergeIcons)
                Toggle(isOn: self.$settings.mergedOverviewAllAccounts) {
                    SettingsRowLabel(
                        L("Show all accounts in Overview"),
                        subtitle: L(
                            "Expand cached account usage. The six-provider limit still applies."))
                }
                .disabled(!self.settings.mergeIcons)
            } header: {
                Text(L("section_menu_tabs"))
            } footer: {
                SettingsSectionFooter(L("section_menu_tabs_footer"))
            }
        }
    }

    @ViewBuilder
    private var stackedBarsSettings: some View {
        SettingsMenuPicker(
            selection: self.$settings.stackedBarsWindow,
            options: StackedBarsWindow.allCases,
            label: { Text(L("stacked_bars_window_title")).settingsSearchAnchor(L("stacked_bars_window_title")) },
            optionLabel: { window in
                Text(window.label)
            })
        Toggle(L("stacked_bars_show_icons_title"), isOn: self.$settings.stackedBarsShowIcons)
            .settingsSearchAnchor(L("stacked_bars_show_icons_title"))
    }

    private var overviewProviderRow: some View {
        LabeledContent {
            if self.settings.mergeIcons, !self.activeProvidersInOrder.isEmpty {
                Button(L("configure")) {
                    self.isOverviewProviderPopoverPresented = true
                }
                .popover(isPresented: self.$isOverviewProviderPopoverPresented, arrowEdge: .bottom) {
                    self.overviewProviderPopover
                }
            }
        } label: {
            SettingsRowLabel(L("overview_tab_providers_title"), subtitle: self.overviewProviderSubtitle)
        }
    }

    private var overviewProviderSubtitle: String {
        if !self.settings.mergeIcons {
            L("overview_enable_merge_icons_hint")
        } else if self.activeProvidersInOrder.isEmpty {
            L("overview_no_providers_hint")
        } else {
            self.overviewProviderSelectionSummary
        }
    }

    private var overviewProviderPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.overviewProviderLimitText())
                .font(.headline)
            Text(L("overview_rows_follow_order"))
                .font(.footnote)
                .foregroundStyle(.tertiary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(self.activeProvidersInOrder, id: \.self) { provider in
                        Toggle(
                            isOn: Binding(
                                get: { self.overviewSelectedProviders.contains(provider) },
                                set: { shouldSelect in
                                    self.setOverviewProviderSelection(provider: provider, isSelected: shouldSelect)
                                })) {
                            Text(self.providerDisplayName(provider))
                                .font(.body)
                        }
                        .toggleStyle(.checkbox)
                        .disabled(
                            !self.overviewSelectedProviders.contains(provider) &&
                                self.overviewSelectedProviders.count >= Self.maxOverviewProviders)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(12)
        .frame(width: 280)
    }

    private var activeProvidersInOrder: [ProviderInstanceID] {
        self.store.enabledProvidersForDisplay()
    }

    private var mergedIconPresentation: MergedIconPresentation {
        self.settings.mergedIconPresentation(activeProviders: self.store.enabledFirstPartyProvidersForDisplay())
    }

    private func stackedRowProviderPicker(
        title: String,
        selection: Binding<UsageProvider?>,
        excluding: UsageProvider?,
        automaticProvider: UsageProvider) -> some View
    {
        SettingsMenuPicker(
            selection: selection,
            options: [nil] + self.mergedIconPresentation.eligibleProviders.filter { $0 != excluding },
            label: { Text(title) },
            optionLabel: { provider in
                Text(provider.map(self.providerDisplayName)
                    ?? "\(L("Automatic")) (\(self.providerDisplayName(automaticProvider)))")
            })
    }

    private var overviewSelectedProviders: [ProviderInstanceID] {
        self.settings.resolvedMergedOverviewProviders(
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }

    private var overviewProviderSelectionSummary: String {
        let selectedNames = self.overviewSelectedProviders.map(self.providerDisplayName)
        guard !selectedNames.isEmpty else { return L("overview_no_providers_selected") }
        return selectedNames.joined(separator: ", ")
    }

    private func providerDisplayName(_ instanceID: ProviderInstanceID) -> String {
        if let provider = instanceID.firstPartyProvider { return self.providerDisplayName(provider) }
        return UserProviderPluginRegistry.plugin(for: instanceID)?.manifest.name ?? instanceID.rawValue
    }

    private func providerDisplayName(_ provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }

    private func setOverviewProviderSelection(provider: ProviderInstanceID, isSelected: Bool) {
        _ = self.settings.setMergedOverviewProviderSelection(
            provider: provider,
            isSelected: isSelected,
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }

    private func reconcileOverviewSelection() {
        _ = self.settings.reconcileMergedOverviewSelectedProviders(
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }
}
