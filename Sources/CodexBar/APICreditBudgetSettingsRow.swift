import CodexBarCore
import SwiftUI

/// Prepaid balance and "as of" day for one provider; clearing the amount removes the budget.
@MainActor
struct APICreditBudgetSettingsRow: View {
    @Bindable var settings: SettingsStore
    let provider: UsageProvider

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(L("api_credits_amount_placeholder"), value: self.amount, format: .number)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                DatePicker(L("api_credits_since_title"), selection: self.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(self.settings.apiCreditBudget(for: self.provider) == nil)
            }
        } label: {
            Text(ProviderDescriptorRegistry.descriptor(for: self.provider).metadata.displayName)
        }
    }

    private var amount: Binding<Double?> {
        Binding(
            get: { self.settings.apiCreditBudget(for: self.provider)?.amount },
            set: { newValue in
                let startDay = self.settings.apiCreditBudget(for: self.provider)?.startDay
                    ?? APICreditBudget.dayKey(for: Date(), calendar: .current)
                self.settings.setAPICreditBudget(
                    newValue.flatMap { APICreditBudget(amount: $0, startDay: startDay) },
                    for: self.provider)
            })
    }

    private var startDate: Binding<Date> {
        Binding(
            get: {
                self.settings.apiCreditBudget(for: self.provider)
                    .flatMap { APICreditBudget.date(forDayKey: $0.startDay, calendar: .current) } ?? Date()
            },
            set: { newDate in
                guard let amount = self.settings.apiCreditBudget(for: self.provider)?.amount else { return }
                self.settings.setAPICreditBudget(
                    APICreditBudget(amount: amount, startDay: APICreditBudget.dayKey(for: newDate, calendar: .current)),
                    for: self.provider)
            })
    }
}
