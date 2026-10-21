import SwiftUI
import SwiftData

struct DailyTargetCard: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \SavingsGoal.updatedAt, order: .reverse) private var goals: [SavingsGoal]
    @Query private var records: [DailyRecord]
    @Query private var expenses: [VehicleExpense]
    @Query private var contributions: [SavingsContribution]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            card(now: timeline.date)
        }
    }

    @ViewBuilder
    private func card(now: Date) -> some View {
        if let goal = goals.first {
            let progress = FinanceMath.progress(goal: goal, contributions: contributions, asOf: now)
            if progress.remaining == 0 {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Meta cumplida", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(Cappuccino.positive(scheme))
                        Text(goal.name).font(.title3.weight(.semibold)).fontDesign(.rounded)
                        AmountRow(title: "Dinero apartado", amount: progress.saved, color: Cappuccino.positive(scheme))
                        Text("Tus aportes registrados ya cubren el objetivo. Puedes seguir ahorrando o actualizar tu meta.")
                            .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                    }
                }
            } else if let target = FinanceMath.dailyTarget(goal: goal, contributions: contributions, records: records, expenses: expenses, now: now) {
                targetCard(target)
            } else {
                unavailableTarget(goal: goal, remaining: progress.remaining, now: now)
            }
        } else {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Tu próximo turno con una meta", systemImage: "sun.horizon").font(.headline)
                    Text("Guarda un objetivo en Mi meta para ver cuánto necesitas generar y cuánto dinero apartar cada día.")
                        .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                }
            }
        }
    }

    private func targetCard(_ target: DailyTarget) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionEyebrow(title: target.isToday ? "Tu objetivo de hoy" : "Tu próximo turno")
                Label(target.isToday ? "Hoy" : Cappuccino.date(target.date), systemImage: "sun.horizon")
                    .font(.headline)
                if !target.isToday {
                    Text("El objetivo se muestra para el próximo día laboral de tu horario.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                Text("Bruto mínimo a generar").font(.subheadline)
                Text(Cappuccino.money(target.minimumGross))
                    .font(.largeTitle.weight(.bold)).fontDesign(.rounded).monospacedDigit()
                    .minimumScaleFactor(0.65).lineLimit(1)
                VStack(alignment: .leading, spacing: 12) {
                    AmountRow(title: "Cuota neta para ahorrar", amount: target.dailySavings, color: Cappuccino.positive(scheme))
                    AmountRow(title: "Bencina del turno", amount: target.fuelBudget, color: Cappuccino.negative(scheme))
                    AmountRow(title: "Otros gastos registrados", amount: target.otherExpenses, color: Cappuccino.negative(scheme))
                    Text("La bencina usa tu estimación hasta que guardas el gasto real del turno.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    AmountRow(title: "Ingreso bruto registrado", amount: target.grossRecorded)
                    AmountRow(title: "Falta generar", amount: target.remainingGross)
                    AmountRow(title: "Neto registrado", amount: target.netRecorded,
                              color: target.netRecorded >= 0 ? Cappuccino.positive(scheme) : Cappuccino.negative(scheme))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    AmountRow(title: "Ya apartaste para tu meta", amount: target.contributedToday, color: Cappuccino.positive(scheme))
                    AmountRow(title: target.isToday ? "Falta apartar de la cuota" : "Ahorro previsto para ese turno",
                              amount: target.isToday ? target.remainingToSaveToday : target.dailySavings)
                }
                Text("\(target.remainingWorkdays) días laborales restantes · hasta el \(Cappuccino.date(target.endDate)), sin incluir esa fecha.")
                    .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                Text("Los ingresos y el neto no son ahorro automático. Usa «Aparté dinero» en Mi meta cuando hayas separado ese dinero.")
                    .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
            }
        }
    }

    private func unavailableTarget(goal: SavingsGoal, remaining: Int, now: Date) -> some View {
        let endDate = Calendar.current.date(byAdding: .month, value: goal.months, to: Calendar.current.startOfDay(for: goal.startDate))
        let expired = endDate.map { Calendar.current.startOfDay(for: now) >= Calendar.current.startOfDay(for: $0) } ?? false
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(expired ? "El plazo de tu meta terminó" : "No quedan turnos dentro del plazo", systemImage: "calendar.badge.exclamationmark")
                    .font(.headline).foregroundStyle(Cappuccino.negative(scheme))
                if let endDate {
                    Text("Fecha de término: \(Cappuccino.date(endDate)), sin incluir ese día.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                AmountRow(title: "Te falta ahorrar", amount: remaining)
                Text("Tus aportes siguen guardados. Actualiza el plazo en Mi meta para calcular una nueva cuota diaria.")
                    .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
            }
        }
    }
}
