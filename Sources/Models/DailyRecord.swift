import Foundation
import SwiftData

@Model
final class DailyRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var grossIncome: Int
    var fuelExpense: Int
    var createdAt: Date

    var netIncome: Int {
        grossIncome - fuelExpense
    }

    init(
        date: Date,
        grossIncome: Int,
        fuelExpense: Int,
        calendar: Calendar = .current
    ) {
        self.id = UUID()
        self.date = calendar.startOfDay(for: date)
        self.grossIncome = max(0, grossIncome)
        self.fuelExpense = max(0, fuelExpense)
        self.createdAt = .now
    }
}
