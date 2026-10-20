import CodexBarCore
import SwiftUI

@MainActor
struct MenuBarPane: View {
    private static let maxOverviewProviders = SettingsStore.mergedOverviewProviderLimit

    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    static func overviewProviderLimitText(limit: Int = Self.maxOverviewProviders) -> String {
        L("overview_choose_providers", String(limit))
    }

    static func inactiveDisplayContrastAvailable(for style: MenuBarIconStyle) -> Bool {
        style == .iconAndPercent
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
            guard isEnabled else { return }
            self.reconcileOverviewSelection()
        }
        .onChange(of: self.activeProvidersInOrder) { _, _ in
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
                    label: {
                        SettingsRowLabel(
                            L("menu_bar_style_title"),
                            subtitle: L("menu_bar_style_subtitle"))
                    },
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
            SettingsSectionFooter(L("menu_bar_layout_footer"))
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

                if !self.activeProvidersInOrder.isEmpty {
                    PinnedProviderZonesView(
                        settings: self.settings,
                        enabled: self.store.enabledFirstPartyProvidersForDisplay(),
                        allEnabled: self.activeProvidersInOrder,
                        limit: Self.maxOverviewProviders)
                }
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

    private func providerDisplayName(_ provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }

    private func reconcileOverviewSelection() {
        _ = self.settings.reconcileMergedOverviewSelectedProviders(
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }
}
