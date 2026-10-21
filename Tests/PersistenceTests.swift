import Foundation
import SwiftData
import XCTest
@testable import SavingsApp

@MainActor
final class PersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([DailyRecord.self, SavingsGoal.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeContext(for container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Santiago")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testDailyRecordCanBeSavedAndFetchedWithNegativeNetIncome() throws {
        let container = try makeContainer()
        let writingContext = makeContext(for: container)
        let record = DailyRecord(
            date: date(2026, 10, 21, hour: 18),
            grossIncome: 18_000,
            fuelExpense: 22_000,
            calendar: calendar
        )
        writingContext.insert(record)
        try writingContext.save()

        let readingContext = makeContext(for: container)
        let records = try readingContext.fetch(FetchDescriptor<DailyRecord>())
        XCTAssertEqual(records.count, 1)
        let saved = try XCTUnwrap(records.first)
        XCTAssertEqual(saved.id, record.id)
        XCTAssertEqual(saved.date, date(2026, 10, 21))
        XCTAssertEqual(saved.grossIncome, 18_000)
        XCTAssertEqual(saved.fuelExpense, 22_000)
        XCTAssertEqual(saved.netIncome, -4_000)
    }

    func testUpdatingSavedDailyRecordPreservesIdentityWithoutAddingAnotherEntry() throws {
        let container = try makeContainer()
        let writingContext = makeContext(for: container)
        let record = DailyRecord(
            date: date(2026, 10, 20),
            grossIncome: 35_000,
            fuelExpense: 16_000,
            calendar: calendar
        )
        let originalID = record.id
        writingContext.insert(record)
        try writingContext.save()

        let editingContext = makeContext(for: container)
        let editingRecord = try XCTUnwrap(
            try editingContext.fetch(FetchDescriptor<DailyRecord>()).first
        )
        editingRecord.grossIncome = 48_000
        editingRecord.fuelExpense = 18_500
        try editingContext.save()

        let readingContext = makeContext(for: container)
        let records = try readingContext.fetch(FetchDescriptor<DailyRecord>())
        XCTAssertEqual(records.count, 1)
        let saved = try XCTUnwrap(records.first)
        XCTAssertEqual(saved.id, originalID)
        XCTAssertEqual(saved.date, date(2026, 10, 20))
        XCTAssertEqual(saved.grossIncome, 48_000)
        XCTAssertEqual(saved.fuelExpense, 18_500)
        XCTAssertEqual(saved.netIncome, 29_500)
    }

    func testSavingsGoalReloadsSelectedConfiguration() throws {
        let container = try makeContainer()
        let writingContext = makeContext(for: container)
        let goal = SavingsGoal(
            name: "Fondo de emergencia",
            targetAmount: 1_200_000,
            startDate: date(2026, 10, 21, hour: 14),
            months: 7,
            daysPerWeek: 6,
            dailyFuelEstimate: 18_500,
            calendar: calendar
        )
        writingContext.insert(goal)
        try writingContext.save()

        let readingContext = makeContext(for: container)
        let goals = try readingContext.fetch(FetchDescriptor<SavingsGoal>())
        XCTAssertEqual(goals.count, 1)
        let saved = try XCTUnwrap(goals.first)
        XCTAssertEqual(saved.id, goal.id)
        XCTAssertEqual(saved.name, "Fondo de emergencia")
        XCTAssertEqual(saved.targetAmount, 1_200_000)
        XCTAssertEqual(saved.startDate, date(2026, 10, 21))
        XCTAssertEqual(saved.months, 7)
        XCTAssertEqual(saved.daysPerWeek, 6)
        XCTAssertEqual(saved.dailyFuelEstimate, 18_500)
        XCTAssertEqual(saved.updatedAt, goal.updatedAt)
    }
}
