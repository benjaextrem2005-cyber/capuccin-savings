import Foundation
import XCTest
@testable import SavingsApp

final class SavingsMathTests: XCTestCase {
    private func calendar(timeZone: String = "America/Santiago") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testMonthCountsCalendarWorkdaysRatherThanFourWeeks() {
        let calendar = calendar()
        let start = date(2026, 10, 1, calendar: calendar)
        XCTAssertEqual(SavingsMath.workdays(start: start, months: 1, daysPerWeek: 5, calendar: calendar), 23)
    }

    func testEndOfMonthClampsToLastCalendarDateAndExcludesIt() throws {
        let calendar = calendar()
        let start = date(2026, 1, 31, hour: 15, calendar: calendar)
        let plan = try XCTUnwrap(SavingsMath.plan(
            targetAmount: 20_000, start: start, months: 1,
            daysPerWeek: 5, dailyFuelEstimate: 0, calendar: calendar
        ))
        XCTAssertEqual(plan.workdays, 20)
        XCTAssertEqual(plan.endDate, date(2026, 2, 28, calendar: calendar))
    }

    func testFiveDayWeekUsesWednesdayThroughSundayRegardlessOfLocaleFirstWeekday() {
        var calendar = calendar()
        calendar.firstWeekday = 1
        let start = date(2026, 2, 1, calendar: calendar)
        XCTAssertEqual(SavingsMath.workdays(start: start, months: 1, daysPerWeek: 1, calendar: calendar), 4)
        XCTAssertEqual(SavingsMath.workdays(start: start, months: 1, daysPerWeek: 5, calendar: calendar), 20)
        XCTAssertEqual(SavingsMath.workdays(start: start, months: 1, daysPerWeek: 6, calendar: calendar), 24)
        XCTAssertEqual(SavingsMath.workdays(start: start, months: 1, daysPerWeek: 7, calendar: calendar), 28)
    }

    func testEveryWorkweekLengthMatchesDateByDateReferenceThroughoutTheYear() {
        let calendar = calendar()
        let orderedWeekdays = [4, 5, 6, 7, 1, 2, 3]

        func referenceCount(start: Date, daysPerWeek: Int) -> Int {
            let selectedWeekdays = Set(orderedWeekdays.prefix(daysPerWeek))
            let startDay = calendar.startOfDay(for: start)
            let end = calendar.startOfDay(for: calendar.date(byAdding: .month, value: 1, to: startDay)!)
            var cursor = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startDay)!
            var total = 0
            while calendar.startOfDay(for: cursor) < end {
                if selectedWeekdays.contains(calendar.component(.weekday, from: cursor)) {
                    total += 1
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }
            return total
        }

        for month in 1...12 {
            for day in 1...7 {
                let start = date(2026, month, day, calendar: calendar)
                for daysPerWeek in 1...7 {
                    XCTAssertEqual(
                        SavingsMath.workdays(start: start, months: 1, daysPerWeek: daysPerWeek, calendar: calendar),
                        referenceCount(start: start, daysPerWeek: daysPerWeek),
                        "2026-\(month)-\(day), \(daysPerWeek) días por semana"
                    )
                }
            }
        }

        let october = date(2026, 10, 1, calendar: calendar)
        let expectedOctoberCounts = [4, 9, 14, 19, 23, 27, 31]
        for (index, expected) in expectedOctoberCounts.enumerated() {
            XCTAssertEqual(
                SavingsMath.workdays(start: october, months: 1, daysPerWeek: index + 1, calendar: calendar),
                expected
            )
        }
    }

    func testLeapYearIncludesLeapDay() throws {
        let calendar = calendar()
        let start = date(2024, 2, 1, calendar: calendar)
        let plan = try XCTUnwrap(SavingsMath.plan(
            targetAmount: 2_900, start: start, months: 1,
            daysPerWeek: 7, dailyFuelEstimate: 0, calendar: calendar
        ))
        XCTAssertEqual(plan.workdays, 29)
        XCTAssertEqual(plan.endDate, date(2024, 3, 1, calendar: calendar))
    }

    func testDaylightSavingTransitionsCountLocalDates() {
        let calendar = calendar(timeZone: "America/New_York")
        let spring = date(2026, 3, 1, hour: 18, calendar: calendar)
        let autumn = date(2026, 11, 1, hour: 18, calendar: calendar)
        XCTAssertEqual(SavingsMath.workdays(start: spring, months: 1, daysPerWeek: 7, calendar: calendar), 31)
        XCTAssertEqual(SavingsMath.workdays(start: autumn, months: 1, daysPerWeek: 7, calendar: calendar), 30)
    }

    func testChileMidnightDaylightSavingTransitionDoesNotLoseAWorkday() {
        let calendar = calendar()
        let start = date(2026, 9, 6, hour: 12, calendar: calendar)
        XCTAssertEqual(SavingsMath.workdays(start: start, months: 1, daysPerWeek: 7, calendar: calendar), 30)
        XCTAssertEqual(SavingsMath.workdays(start: start, months: 1, daysPerWeek: 5, calendar: calendar), 21)
    }

    func testDailySavingsRoundsUpAndAddsFuel() throws {
        let calendar = calendar()
        let start = date(2026, 2, 1, calendar: calendar)
        let plan = try XCTUnwrap(SavingsMath.plan(
            targetAmount: 100_001, start: start, months: 1,
            daysPerWeek: 5, dailyFuelEstimate: 16_000, calendar: calendar
        ))
        XCTAssertEqual(plan.workdays, 20)
        XCTAssertEqual(plan.dailySavings, 5_001)
        XCTAssertEqual(plan.minimumDailyGross, 21_001)
        XCTAssertGreaterThanOrEqual(plan.dailySavings * plan.workdays, 100_001)
    }

    func testInvalidPlanInputIsRejected() {
        let calendar = calendar()
        let start = date(2026, 2, 1, calendar: calendar)
        for months in [0, -1] {
            XCTAssertEqual(SavingsMath.workdays(start: start, months: months, daysPerWeek: 5, calendar: calendar), 0)
            XCTAssertNil(SavingsMath.plan(targetAmount: 100, start: start, months: months, daysPerWeek: 5, dailyFuelEstimate: 0, calendar: calendar))
        }
        for days in [-1, 0, 8] {
            XCTAssertEqual(SavingsMath.workdays(start: start, months: 1, daysPerWeek: days, calendar: calendar), 0)
            XCTAssertNil(SavingsMath.plan(targetAmount: 100, start: start, months: 1, daysPerWeek: days, dailyFuelEstimate: 0, calendar: calendar))
        }
        for amount in [-1, 0] {
            XCTAssertNil(SavingsMath.plan(targetAmount: amount, start: start, months: 1, daysPerWeek: 5, dailyFuelEstimate: 0, calendar: calendar))
        }
        XCTAssertNil(SavingsMath.plan(targetAmount: 100, start: start, months: 1, daysPerWeek: 5, dailyFuelEstimate: -1, calendar: calendar))
    }

    func testIntegerRoundingDoesNotOverflowAndExcessiveGrossIsRejected() throws {
        let calendar = calendar()
        let start = date(2026, 2, 1, calendar: calendar)
        let plan = try XCTUnwrap(SavingsMath.plan(
            targetAmount: Int.max, start: start, months: 1,
            daysPerWeek: 5, dailyFuelEstimate: 0, calendar: calendar
        ))
        XCTAssertEqual(plan.dailySavings, Int.max / 20 + 1)
        XCTAssertNil(SavingsMath.plan(
            targetAmount: Int.max, start: start, months: 1,
            daysPerWeek: 5, dailyFuelEstimate: Int.max, calendar: calendar
        ))
    }

    func testAmountParserAcceptsWholeChileanPesos() {
        let accepted: [(String, Int)] = [
            ("0", 0), ("1600", 1_600), ("1.600", 1_600),
            ("$ 1.600", 1_600), ("  $300.000  ", 300_000),
            ("999.999.999", CLPAmount.maximum)
        ]
        for (input, expected) in accepted {
            XCTAssertEqual(CLPAmount.parse(input), expected, input)
        }
    }

    func testAmountParserRejectsFractionsNegativeMalformedAndExcessiveValues() {
        let rejected = [
            "", " ", "$", "-1600", "+1600", "1,5", "1.60", "1.600,00",
            "1,600", "1..600", ".600", "600.", "12.34.567", "0.600",
            "1 600", "$$1600", "1600$", "1000000000", "1.000.000.000",
            "999999999999999999999999999999", "١٦٠٠", "1e3"
        ]
        for input in rejected {
            XCTAssertNil(CLPAmount.parse(input), input)
        }
    }

    func testDailyRecordNormalizesDateAndPreservesLosses() {
        let calendar = calendar()
        let start = date(2026, 10, 21, hour: 18, calendar: calendar)
        let record = DailyRecord(date: start, grossIncome: 10_000, fuelExpense: 16_000, calendar: calendar)
        XCTAssertEqual(record.date, date(2026, 10, 21, calendar: calendar))
        XCTAssertEqual(record.netIncome, -6_000)
    }

    func testSavingsGoalDefaultsToFiveWorkingDays() {
        let goal = SavingsGoal(name: "  Fondo de emergencia  ", targetAmount: 500_000)
        XCTAssertEqual(goal.name, "Fondo de emergencia")
        XCTAssertEqual(goal.daysPerWeek, 5)
        XCTAssertEqual(goal.dailyFuelEstimate, 0)
    }
}
