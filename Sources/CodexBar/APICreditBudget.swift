import CodexBarCore
import Foundation

/// A prepaid API balance the user entered. Neither the Anthropic nor the OpenAI Admin API reports a
/// remaining balance, so "credits left" is this amount minus vendor-reported spend after `startDay`.
struct APICreditBudget: Equatable, Sendable {
    /// Any provider with cost history can carry a prepaid balance; only vendor-reported spend draws it down.
    static func supports(_ provider: UsageProvider) -> Bool {
        ProviderDescriptorRegistry.descriptor(for: provider).tokenCost.supportsTokenCost
    }

    struct Status: Equatable, Sendable {
        let spent: Double
        let remaining: Double
        /// False when the loaded cost history starts after `startDay`, so `spent` is a lower bound.
        let coversStartDay: Bool
    }

    let amount: Double
    /// Local calendar day (`yyyy-MM-dd`) the balance was checked; that day's spend is already in it.
    let startDay: String

    init?(amount: Double, startDay: String) {
        guard amount.isFinite, amount > 0, Self.isDayKey(startDay) else { return nil }
        self.amount = amount
        self.startDay = startDay
    }

    func status(
        daily: [CostUsageDailyReport.Entry],
        historyDays: Int,
        now: Date,
        calendar: Calendar) -> Status
    {
        // Sources report days in different formats; normalize to zero-padded ISO keys, whose string
        // order is chronological. Entries whose date cannot be read are left out rather than guessed.
        let spent = daily
            .filter { entry in
                CostUsageTokenSnapshot.localDayKey(for: entry.date, calendar: calendar)
                    .map { $0 > self.startDay } ?? false
            }
            .compactMap(\.costUSD)
            .reduce(0, +)
        let historyStart = calendar.date(
            byAdding: .day,
            value: -(max(1, historyDays) - 1),
            to: calendar.startOfDay(for: now))
        let coversStartDay = historyStart.map { Self.dayKey(for: $0, calendar: calendar) <= self.startDay } ?? false
        return Status(spent: spent, remaining: self.amount - spent, coversStartDay: coversStartDay)
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func date(forDayKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func isDayKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        return parts.count == 3 && parts.map(\.count) == [4, 2, 2] && parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }
}

extension SettingsStore {
    func apiCreditBudget(for provider: UsageProvider) -> APICreditBudget? {
        guard let amount = self.apiCreditBudgetAmountsRaw[provider.rawValue],
              let startDay = self.apiCreditBudgetStartDaysRaw[provider.rawValue]
        else { return nil }
        return APICreditBudget(amount: amount, startDay: startDay)
    }

    func setAPICreditBudget(_ budget: APICreditBudget?, for provider: UsageProvider) {
        var amounts = self.apiCreditBudgetAmountsRaw
        var startDays = self.apiCreditBudgetStartDaysRaw
        amounts[provider.rawValue] = budget?.amount
        startDays[provider.rawValue] = budget?.startDay
        self.apiCreditBudgetAmountsRaw = amounts
        self.apiCreditBudgetStartDaysRaw = startDays
    }
}
