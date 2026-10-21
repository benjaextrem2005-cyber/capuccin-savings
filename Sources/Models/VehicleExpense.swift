import Foundation
import SwiftData

@Model
final class VehicleExpense {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Int
    var category: String
    var note: String
    var createdAt: Date

    static let categories = ["Mantención", "Peajes", "Estacionamiento", "Reparaciones", "Seguro", "Otros"]

    init(
        date: Date,
        amount: Int,
        category: String,
        note: String = "",
        calendar: Calendar = .current
    ) {
        self.id = UUID()
        self.date = calendar.startOfDay(for: date)
        self.amount = max(0, amount)
        self.category = Self.categories.contains(category) ? category : "Otros"
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = .now
    }
}
