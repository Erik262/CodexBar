import CodexBarCore
import Foundation

/// A prepaid API balance the user entered. Neither the Anthropic nor the OpenAI Admin API reports a
/// remaining balance, so "credits left" is this amount minus the reported spend since `startDay`.
struct APICreditBudget: Equatable, Sendable {
    static let supportedProviders: [UsageProvider] = [.claude, .codex, .openai]

    struct Status: Equatable, Sendable {
        let spent: Double
        let remaining: Double
        /// False when the loaded cost history starts after `startDay`, so `spent` is a lower bound.
        let coversStartDay: Bool
    }

    let amount: Double
    /// Local calendar day (`yyyy-MM-dd`) the balance was last topped up or checked.
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
        // Day keys are zero-padded ISO dates, so string order is chronological order.
        let spent = daily
            .filter { $0.date >= self.startDay }
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
