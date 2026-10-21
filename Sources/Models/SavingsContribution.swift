import Foundation
import SwiftData

@Model
final class SavingsContribution {
    @Attribute(.unique) var id: UUID
    var goalID: UUID
    var date: Date
    var amount: Int
    var createdAt: Date

    init(goalID: UUID, date: Date, amount: Int, calendar: Calendar = .current) {
        self.id = UUID()
        self.goalID = goalID
        self.date = calendar.startOfDay(for: date)
        self.amount = max(0, amount)
        self.createdAt = .now
    }
}
