import Foundation
import XCTest
@testable import SavingsApp

final class FinanceMathTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Santiago")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func goal(amount: Int = 200_000, fuel: Int = 16_000) -> SavingsGoal {
        SavingsGoal(name: "Ahorro real", targetAmount: amount, startDate: date(2026, 2, 4),
                    months: 1, daysPerWeek: 5, dailyFuelEstimate: fuel, calendar: calendar)
    }

    private func contribution(_ amount: Int, to goal: SavingsGoal, day: Int) -> SavingsContribution {
        SavingsContribution(goalID: goal.id, date: date(2026, 2, day), amount: amount, calendar: calendar)
    }

    private func record(_ day: Int, gross: Int, fuel: Int) -> DailyRecord {
        DailyRecord(date: date(2026, 2, day), grossIncome: gross, fuelExpense: fuel, calendar: calendar)
    }

    private func expense(_ day: Int, amount: Int) -> VehicleExpense {
        VehicleExpense(date: date(2026, 2, day), amount: amount, category: "Peajes", calendar: calendar)
    }

    func testDayIncludesOtherExpensesAndPreservesNegativeNet() {
        let totals = FinanceMath.day(date(2026, 2, 4, hour: 19),
            records: [record(4, gross: 18_000, fuel: 22_000), record(5, gross: 999_000, fuel: 0)],
            expenses: [expense(4, amount: 2_000), expense(4, amount: 4_000), expense(5, amount: 50_000)],
            calendar: calendar)
        XCTAssertEqual(totals.gross, 18_000)
        XCTAssertEqual(totals.fuel, 22_000)
        XCTAssertEqual(totals.otherExpenses, 6_000)
        XCTAssertEqual(totals.expenses, 28_000)
        XCTAssertEqual(totals.net, -10_000)
    }

    func testProgressOnlyCountsRealContributionsForThisGoalThroughToday() {
        let goal = goal()
        let otherGoal = self.goal()
        let contributions = [contribution(20_000, to: goal, day: 3), contribution(30_000, to: goal, day: 4),
                             contribution(100_000, to: goal, day: 5), contribution(150_000, to: otherGoal, day: 4)]
        let progress = FinanceMath.progress(goal: goal, contributions: contributions,
                                           asOf: date(2026, 2, 4, hour: 19), calendar: calendar)
        XCTAssertEqual(progress.saved, 50_000)
        XCTAssertEqual(progress.remaining, 150_000)
        XCTAssertEqual(progress.fraction, 0.25, accuracy: 0.000_001)
    }

    func testProgressCapsFractionAndRemainingAfterExceedingGoal() {
        let goal = goal()
        let progress = FinanceMath.progress(goal: goal, contributions: [contribution(250_000, to: goal, day: 4)],
                                           asOf: date(2026, 2, 4), calendar: calendar)
        XCTAssertEqual(progress.saved, 250_000)
        XCTAssertEqual(progress.remaining, 0)
        XCTAssertEqual(progress.fraction, 1)
    }

    func testDailyQuotaRoundsUpAndUsesEstimatedFuelWithoutADailyRecord() throws {
        let target = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal(amount: 200_001), contributions: [],
            records: [], expenses: [], now: date(2026, 2, 4), calendar: calendar))
        XCTAssertTrue(target.isToday)
        XCTAssertEqual(target.remainingWorkdays, 20)
        XCTAssertEqual(target.dailySavings, 10_001)
        XCTAssertEqual(target.fuelBudget, 16_000)
        XCTAssertEqual(target.minimumGross, 26_001)
        XCTAssertEqual(target.remainingGross, 26_001)
        XCTAssertEqual(target.remainingToSaveToday, 10_001)
        XCTAssertEqual(target.endDate, date(2026, 3, 4))
    }

    func testAddingTodaysPartialContributionDoesNotReduceQuotaTwice() throws {
        let goal = goal()
        let before = [contribution(20_000, to: goal, day: 3)]
        let after = before + [contribution(6_000, to: goal, day: 4)]
        let original = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal, contributions: before,
            records: [], expenses: [], now: date(2026, 2, 4), calendar: calendar))
        let target = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal, contributions: after,
            records: [], expenses: [], now: date(2026, 2, 4), calendar: calendar))
        XCTAssertEqual(original.dailySavings, 9_000)
        XCTAssertEqual(target.dailySavings, original.dailySavings)
        XCTAssertEqual(target.contributedToday, 6_000)
        XCTAssertEqual(target.remainingToSaveToday, 3_000)
        XCTAssertEqual(FinanceMath.progress(goal: goal, contributions: after, asOf: date(2026, 2, 4), calendar: calendar).remaining, 174_000)
    }

    func testRollingQuotaAdjustsToRemainingWorkdaysAndPastSavings() throws {
        let goal = goal(amount: 200_001)
        let target = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal,
            contributions: [contribution(50_000, to: goal, day: 8)], records: [], expenses: [],
            now: date(2026, 2, 11), calendar: calendar))
        XCTAssertEqual(target.remainingWorkdays, 15)
        XCTAssertEqual(target.dailySavings, 10_001)
        let withoutSavings = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal, contributions: [],
            records: [], expenses: [], now: date(2026, 2, 11), calendar: calendar))
        XCTAssertEqual(withoutSavings.dailySavings, 13_334)
    }

    func testRestDayTargetsNextWednesdayAndIgnoresFutureEntries() throws {
        let goal = goal()
        let otherGoal = self.goal()
        let target = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal,
            contributions: [contribution(50_000, to: goal, day: 9), contribution(100_000, to: goal, day: 12),
                            contribution(150_000, to: otherGoal, day: 9)],
            records: [record(11, gross: 200_000, fuel: 90_000)], expenses: [expense(11, amount: 99_000)],
            now: date(2026, 2, 9), calendar: calendar))
        XCTAssertEqual(target.date, date(2026, 2, 11))
        XCTAssertFalse(target.isToday)
        XCTAssertEqual(target.remainingWorkdays, 15)
        XCTAssertEqual(target.dailySavings, 10_000)
        XCTAssertEqual(target.fuelBudget, 16_000)
        XCTAssertEqual(target.otherExpenses, 0)
        XCTAssertEqual(target.grossRecorded, 0)
        XCTAssertEqual(target.netRecorded, 0)
        XCTAssertEqual(target.minimumGross, 26_000)
        XCTAssertEqual(target.contributedToday, 0)
        XCTAssertEqual(target.remainingToSaveToday, 0)
    }

    func testBeforeStartUsesUpcomingShiftAndContributionsAlreadySaved() throws {
        let goal = goal()
        let target = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal,
            contributions: [contribution(20_000, to: goal, day: 3)], records: [], expenses: [],
            now: date(2026, 2, 3), calendar: calendar))
        XCTAssertEqual(target.date, date(2026, 2, 4))
        XCTAssertFalse(target.isToday)
        XCTAssertEqual(target.dailySavings, 9_000)
    }

    func testActualFuelAndOtherExpensesReplaceEstimateInGrossTarget() throws {
        let goal = goal()
        let records = [record(4, gross: 21_000, fuel: 8_000)]
        let target = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal, contributions: [],
            records: records, expenses: [expense(4, amount: 1_500)], now: date(2026, 2, 4), calendar: calendar))
        XCTAssertEqual(target.fuelBudget, 8_000)
        XCTAssertEqual(target.otherExpenses, 1_500)
        XCTAssertEqual(target.minimumGross, 19_500)
        XCTAssertEqual(target.grossRecorded, 21_000)
        XCTAssertEqual(target.netRecorded, 11_500)
        XCTAssertEqual(target.remainingGross, 0)
        XCTAssertEqual(target.contributedToday, 0)
        XCTAssertEqual(target.remainingToSaveToday, 10_000)
        XCTAssertEqual(FinanceMath.progress(goal: goal, contributions: [], asOf: date(2026, 2, 4), calendar: calendar).saved, 0)
    }

    func testExplicitZeroFuelDoesNotFallBackToEstimate() throws {
        let target = try XCTUnwrap(FinanceMath.dailyTarget(goal: goal(), contributions: [],
            records: [record(4, gross: 5_000, fuel: 0)], expenses: [], now: date(2026, 2, 4), calendar: calendar))
        XCTAssertEqual(target.fuelBudget, 0)
        XCTAssertEqual(target.minimumGross, 10_000)
        XCTAssertEqual(target.remainingGross, 5_000)
    }

    func testCompletedExpiredAndZeroGoalsHaveNoDailyTarget() {
        let goal = goal()
        XCTAssertNil(FinanceMath.dailyTarget(goal: goal, contributions: [contribution(200_000, to: goal, day: 4)],
            records: [], expenses: [], now: date(2026, 2, 4), calendar: calendar))
        XCTAssertNil(FinanceMath.dailyTarget(goal: goal, contributions: [], records: [], expenses: [],
            now: date(2026, 3, 4), calendar: calendar))
        XCTAssertNil(FinanceMath.dailyTarget(goal: goal, contributions: [], records: [], expenses: [],
            now: date(2026, 3, 2), calendar: calendar))
        XCTAssertNil(FinanceMath.dailyTarget(goal: self.goal(amount: 0), contributions: [], records: [], expenses: [],
            now: date(2026, 2, 4), calendar: calendar))
    }

    func testWeekUsesWednesdayThroughTuesdayAndComparesOnlyElapsedDays() {
        let previousRecords = [
            DailyRecord(date: date(2026, 1, 28), grossIncome: 30_000, fuelExpense: 5_000, calendar: calendar),
            DailyRecord(date: date(2026, 1, 29), grossIncome: 20_000, fuelExpense: 5_000, calendar: calendar),
            DailyRecord(date: date(2026, 1, 31), grossIncome: 999_999, fuelExpense: 0, calendar: calendar)
        ]
        let previousExpense = VehicleExpense(date: date(2026, 1, 30), amount: 2_000, category: "Peajes", calendar: calendar)
        let summary = FinanceMath.week(containing: date(2026, 2, 6, hour: 19),
            records: previousRecords + [record(4, gross: 50_000, fuel: 10_000), record(5, gross: 40_000, fuel: 8_000),
                                        record(7, gross: 900_000, fuel: 0)],
            expenses: [previousExpense, expense(4, amount: 2_000), expense(6, amount: 3_000), expense(8, amount: 100_000)],
            calendar: calendar)
        XCTAssertEqual(summary.start, date(2026, 2, 4))
        XCTAssertEqual(summary.end, date(2026, 2, 11))
        XCTAssertEqual(summary.elapsedDays, 3)
        XCTAssertEqual(summary.days.count, 7)
        XCTAssertEqual(summary.days.map(\.net), [38_000, 32_000, -3_000, 0, 0, 0, 0])
        XCTAssertEqual(summary.gross, 90_000)
        XCTAssertEqual(summary.expenses, 23_000)
        XCTAssertEqual(summary.net, 67_000)
        XCTAssertTrue(summary.hasPreviousData)
        XCTAssertEqual(summary.previousComparableNet, 38_000)
        XCTAssertEqual(summary.comparisonDelta, 29_000)
    }

    func testWeeklyComparisonDistinguishesNoDataFromARecordedZero() {
        let now = date(2026, 2, 4)
        let empty = FinanceMath.week(containing: now, records: [], expenses: [], calendar: calendar)
        XCTAssertFalse(empty.hasPreviousData)
        XCTAssertEqual(empty.elapsedDays, 1)
        let recordedZero = DailyRecord(date: date(2026, 1, 28), grossIncome: 0, fuelExpense: 0, calendar: calendar)
        let zero = FinanceMath.week(containing: now, records: [recordedZero], expenses: [], calendar: calendar)
        XCTAssertTrue(zero.hasPreviousData)
        XCTAssertEqual(zero.previousComparableNet, 0)
    }

    func testFullWeekIncludesMondayAndTuesdayIfFinancialEntriesExist() {
        let summary = FinanceMath.week(containing: date(2026, 2, 10),
            records: [record(9, gross: 10_000, fuel: 2_000)], expenses: [expense(10, amount: 1_000)], calendar: calendar)
        XCTAssertEqual(summary.elapsedDays, 7)
        XCTAssertEqual(summary.days[5].net, 8_000)
        XCTAssertEqual(summary.days[6].net, -1_000)
        XCTAssertEqual(summary.net, 7_000)
    }

    func testWeeklyDatesSurviveChileMidnightDaylightSavingChange() {
        let sunday = DailyRecord(date: date(2026, 9, 6, hour: 18), grossIncome: 20_000, fuelExpense: 5_000, calendar: calendar)
        let nextMonday = DailyRecord(date: date(2026, 9, 7), grossIncome: 100_000, fuelExpense: 0, calendar: calendar)
        let summary = FinanceMath.week(containing: date(2026, 9, 6, hour: 19),
                                       records: [sunday, nextMonday], expenses: [], calendar: calendar)
        XCTAssertEqual(summary.start, date(2026, 9, 2))
        XCTAssertEqual(summary.end, date(2026, 9, 9))
        XCTAssertEqual(summary.elapsedDays, 5)
        XCTAssertEqual(summary.days.map { calendar.component(.day, from: $0.date) }, [2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(summary.days[4].net, 15_000)
        XCTAssertEqual(summary.days[5].net, 0)
        XCTAssertEqual(summary.net, 15_000)
    }

    func testNewModelsNormalizeDatesAmountsAndExpenseDetails() {
        let goal = goal()
        let contribution = SavingsContribution(goalID: goal.id, date: date(2026, 2, 4, hour: 19), amount: -10, calendar: calendar)
        XCTAssertEqual(contribution.date, date(2026, 2, 4))
        XCTAssertEqual(contribution.amount, 0)
        let expense = VehicleExpense(date: date(2026, 2, 4, hour: 20), amount: -20, category: "Desconocida", note: "  Repuesto  ", calendar: calendar)
        XCTAssertEqual(expense.date, date(2026, 2, 4))
        XCTAssertEqual(expense.amount, 0)
        XCTAssertEqual(expense.category, "Otros")
        XCTAssertEqual(expense.note, "Repuesto")
        XCTAssertEqual(VehicleExpense.categories, ["Mantención", "Peajes", "Estacionamiento", "Reparaciones", "Seguro", "Otros"])
    }
}
