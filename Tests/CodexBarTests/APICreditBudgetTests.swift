import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct APICreditBudgetTests {
    @Test
    func `budgets follow each provider's cost support`() {
        #expect(APICreditBudget.supports(.claude))
        #expect(APICreditBudget.supports(.codex))
        #expect(APICreditBudget.supports(.openai))
        #expect(APICreditBudget.supports(.openrouter))
        #expect(!APICreditBudget.supports(.gemini))
    }

    @Test
    func `credits left subtract spend after the start day`() throws {
        let calendar = try Self.utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)))
        let budget = try #require(APICreditBudget(amount: 50, startDay: "2026-07-10"))
        let status = budget.status(
            daily: [
                Self.entry("2026-07-09", cost: 100),
                Self.entry("2026-07-10", cost: 4),
                Self.entry("2026-07-14", cost: 6.5),
                Self.entry("2026-07-15", cost: nil),
            ],
            historyDays: 30,
            now: now,
            calendar: calendar)

        #expect(status.spent == 6.5)
        #expect(status.remaining == 43.5)
        #expect(status.coversStartDay)
    }

    @Test
    func `timestamped daily keys compare by their local day`() throws {
        let calendar = try Self.utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)))
        let budget = try #require(APICreditBudget(amount: 30, startDay: "2026-07-10"))
        let status = budget.status(
            daily: [
                Self.entry("2026-07-01T08:00:00Z", cost: 500),
                Self.entry("2026-07-12T08:00:00Z", cost: 5),
            ],
            historyDays: 30,
            now: now,
            calendar: calendar)

        #expect(status.spent == 5)
        #expect(status.remaining == 25)
    }

    @Test
    func `a start day before the loaded history is flagged as a lower bound`() throws {
        let calendar = try Self.utcCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)))
        let budget = try #require(APICreditBudget(amount: 20, startDay: "2026-06-01"))

        let status = budget.status(daily: [], historyDays: 7, now: now, calendar: calendar)

        #expect(!status.coversStartDay)
        #expect(status.remaining == 20)
    }

    @Test
    func `invalid budgets are rejected`() {
        #expect(APICreditBudget(amount: 0, startDay: "2026-07-10") == nil)
        #expect(APICreditBudget(amount: -5, startDay: "2026-07-10") == nil)
        #expect(APICreditBudget(amount: 5, startDay: "July 10") == nil)
        #expect(APICreditBudget(amount: 5, startDay: "2026-7-10") == nil)
    }

    @Test
    func `budgets persist per provider and clear independently`() throws {
        let defaults = InMemoryUserDefaults()
        let settings = testSettingsStore(suiteName: #function, userDefaults: defaults)
        let openAI = try #require(APICreditBudget(amount: 25, startDay: "2026-07-01"))
        let claude = try #require(APICreditBudget(amount: 100, startDay: "2026-06-15"))
        settings.setAPICreditBudget(openAI, for: .openai)
        settings.setAPICreditBudget(claude, for: .claude)

        let reloaded = testSettingsStore(suiteName: #function, userDefaults: defaults)
        #expect(reloaded.apiCreditBudget(for: .openai) == openAI)
        #expect(reloaded.apiCreditBudget(for: .claude) == claude)
        #expect(reloaded.apiCreditBudget(for: .codex) == nil)

        reloaded.setAPICreditBudget(nil, for: .openai)
        #expect(reloaded.apiCreditBudget(for: .openai) == nil)
        #expect(reloaded.apiCreditBudget(for: .claude) == claude)
    }

    @Test
    func `day keys round trip through dates`() throws {
        let calendar = try Self.utcCalendar()
        let date = try #require(APICreditBudget.date(forDayKey: "2026-02-03", calendar: calendar))
        #expect(APICreditBudget.dayKey(for: date, calendar: calendar) == "2026-02-03")
    }

    private static func utcCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        return calendar
    }

    private static func entry(_ date: String, cost: Double?) -> CostUsageDailyReport.Entry {
        CostUsageDailyReport.Entry(
            date: date,
            inputTokens: nil,
            outputTokens: nil,
            totalTokens: nil,
            costUSD: cost,
            modelsUsed: nil,
            modelBreakdowns: nil)
    }
}
