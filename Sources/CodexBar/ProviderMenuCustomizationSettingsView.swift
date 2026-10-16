import CodexBarCore
import SwiftUI

/// Per-provider menu customization on the provider's Settings page: which menu sections appear and an
/// optional prepaid API balance for providers that report spend.
@MainActor
struct ProviderMenuCustomizationSettingsView: View {
    let provider: UsageProvider
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    var body: some View {
        if self.settings.isProviderEnabled(provider: self.provider, metadata: self.store.metadata(for: self.provider)) {
            Section {
                ProviderMenuPreview(provider: self.provider, settings: self.settings, store: self.store)
            } header: {
                Text(L("menu_preview_title"))
            } footer: {
                SettingsSectionFooter(L("menu_preview_footer"))
            }
        }

        Section {
            if MenuSectionToggle.statusPageLink.applies(to: self.provider) {
                self.statusPagePicker
            }

            ForEach(MenuSectionToggle.allCases.filter {
                $0 != .statusPageLink && $0.applies(to: self.provider)
            }) { section in
                Toggle(section.label, isOn: Binding(
                    get: { self.settings.isMenuSectionVisible(section, for: self.provider) },
                    set: { self.settings.setMenuSection(section, visible: $0, for: self.provider) }))
                    .toggleStyle(.checkbox)
            }

            Button(L("Restore Defaults")) {
                self.settings.resetMenuCustomization(for: self.provider)
            }
            .disabled(!self.settings.hasMenuCustomization(for: self.provider))
        } header: {
            Text(L("section_menu_visibility"))
        } footer: {
            SettingsSectionFooter(L("section_menu_visibility_footer"))
        }

        if APICreditBudget.supports(self.provider) {
            Section {
                APICreditBudgetSettingsRow(settings: self.settings, provider: self.provider)
            } header: {
                Text(L("api_credits_settings_title"))
            } footer: {
                SettingsSectionFooter(L("api_credits_settings_subtitle"))
            }
        }
    }

    private var statusPagePicker: some View {
        Picker(selection: Binding(
            get: { self.settings.statusPagePresentation(for: self.provider) },
            set: { self.settings.setStatusPagePresentation($0, for: self.provider) }))
        {
            ForEach(StatusPagePresentation.options(for: self.provider)) { option in
                Text(option.label).tag(option)
            }
        } label: {
            SettingsRowLabel(L("status_page_presentation_title"), subtitle: self.statusPageSubtitle)
        }
        .pickerStyle(.segmented)
    }

    private var statusPageSubtitle: String? {
        guard self.settings.statusPagePresentation(for: self.provider) == .inline else { return nil }
        return self.settings.statusChecksEnabled
            ? L("status_page_inline_subtitle")
            : L("status_page_inline_requires_checks")
    }
}

/// Live stand-in for the provider's menu: the real usage card plus the link rows, rebuilt as the toggles
/// change. The status-bar menu itself closes when Settings takes focus, so it cannot be watched directly.
@MainActor
private struct ProviderMenuPreview: View {
    static let width: CGFloat = 310

    let provider: UsageProvider
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            UsageMenuCardView(model: self.store.menuCardModel(for: self.provider), width: Self.width)
            let rows = self.linkRows
            if !rows.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                ForEach(rows, id: \.self) { row in
                    Label(row.title, systemImage: row.systemImage)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 6)
            }
        }
        .frame(width: Self.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
    }

    private struct LinkRow: Hashable {
        let title: String
        let systemImage: String
    }

    private var linkRows: [LinkRow] {
        let sections: [(MenuSectionToggle, String)] = [
            (.buyCredits, "cart"),
            (.accountActions, MenuDescriptor.MenuActionSystemImage.switchAccount.rawValue),
            (.dashboardLink, MenuDescriptor.MenuActionSystemImage.dashboard.rawValue),
            (.changelogLink, MenuDescriptor.MenuActionSystemImage.changelog.rawValue),
        ]
        var rows = sections.compactMap { section, image -> LinkRow? in
            guard section.applies(to: self.provider),
                  self.settings.isMenuSectionVisible(section, for: self.provider)
            else { return nil }
            return LinkRow(title: section.label, systemImage: image)
        }
        switch self.settings.statusPagePresentation(for: self.provider) {
        case .off:
            break
        case .link:
            rows.append(LinkRow(
                title: L("Status Page"),
                systemImage: MenuDescriptor.MenuActionSystemImage.statusPage.rawValue))
        case .inline:
            rows.append(LinkRow(
                title: "\(L("Status Page")) · \(L("status_page_inline"))",
                systemImage: MenuDescriptor.MenuActionSystemImage.statusPage.rawValue))
        }
        return rows
    }
}
