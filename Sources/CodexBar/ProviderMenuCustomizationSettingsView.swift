import CodexBarCore
import SwiftUI

/// Per-provider menu customization on the provider's Settings page: which menu sections appear and an
/// optional prepaid API balance for providers that report spend.
@MainActor
struct ProviderMenuCustomizationSettingsView: View {
    let provider: UsageProvider
    @Bindable var settings: SettingsStore

    var body: some View {
        Section {
            ForEach(MenuSectionToggle.allCases) { section in
                Toggle(section.label, isOn: Binding(
                    get: { self.settings.isMenuSectionVisible(section, for: self.provider) },
                    set: { self.settings.setMenuSection(section, visible: $0, for: self.provider) }))
                    .toggleStyle(.checkbox)
            }

            Button(L("Restore Defaults")) {
                for section in MenuSectionToggle.allCases {
                    self.settings.setMenuSection(section, visible: true, for: self.provider)
                }
            }
            .disabled(self.settings.hiddenMenuSections(for: self.provider).isEmpty)
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
}
