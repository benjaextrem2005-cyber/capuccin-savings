import Foundation
import SwiftData

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Int
    var startDate: Date
    var months: Int
    var daysPerWeek: Int
    var dailyFuelEstimate: Int
    var updatedAt: Date

    init(
        name: String,
        targetAmount: Int,
        startDate: Date = .now,
        months: Int = 3,
        daysPerWeek: Int = 5,
        dailyFuelEstimate: Int = 0,
        calendar: Calendar = .current
    ) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetAmount = max(0, targetAmount)
        self.startDate = calendar.startOfDay(for: startDate)
        self.months = months
        self.daysPerWeek = daysPerWeek
        self.dailyFuelEstimate = max(0, dailyFuelEstimate)
        self.updatedAt = .now
    }
}
