import Foundation
import SwiftData
import XCTest
@testable import SavingsApp

@MainActor
final class MigrationTests: XCTestCase {
    func testExistingVersionOneStoreKeepsRecordsAndGoalAfterAddingNewModels() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CappuccinoMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("default.store")
        let ids = try writeVersionOneStore(at: url)

        try autoreleasepool {
            let schema = Schema([DailyRecord.self, SavingsGoal.self, SavingsContribution.self, VehicleExpense.self])
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.autosaveEnabled = false

            let records = try context.fetch(FetchDescriptor<DailyRecord>())
            let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(goals.count, 1)
            let record = try XCTUnwrap(records.first)
            let goal = try XCTUnwrap(goals.first)
            XCTAssertEqual(record.id, ids.record)
            XCTAssertEqual(record.grossIncome, 48_000)
            XCTAssertEqual(record.fuelExpense, 16_000)
            XCTAssertEqual(goal.id, ids.goal)
            XCTAssertEqual(goal.name, "Fondo de emergencia")
            XCTAssertEqual(goal.targetAmount, 600_000)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavingsContribution>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<VehicleExpense>()), 0)

            context.insert(VehicleExpense(date: record.date, amount: 2_000, category: "Peajes"))
            context.insert(SavingsContribution(goalID: goal.id, date: record.date, amount: 20_000))
            try context.save()
            let expenses = try context.fetch(FetchDescriptor<VehicleExpense>())
            XCTAssertEqual(FinanceMath.day(record.date, records: records, expenses: expenses).net, 30_000)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavingsContribution>()), 1)
        }
    }

    private func writeVersionOneStore(at url: URL) throws -> (record: UUID, goal: UUID) {
        try autoreleasepool {
            let schema = Schema([DailyRecord.self, SavingsGoal.self])
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let record = DailyRecord(date: Date(), grossIncome: 48_000, fuelExpense: 16_000)
            let goal = SavingsGoal(name: "Fondo de emergencia", targetAmount: 600_000)
            context.insert(record)
            context.insert(goal)
            try context.save()
            return (record.id, goal.id)
        }
    }
}
