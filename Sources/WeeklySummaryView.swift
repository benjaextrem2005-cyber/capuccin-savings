import SwiftUI
import SwiftData
import Charts

struct WeeklySummaryView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DailyRecord.date) private var records: [DailyRecord]
    @Query(sort: \VehicleExpense.date) private var expenses: [VehicleExpense]
    @State private var referenceDate = Date()

    private var summary: WeekSummary {
        FinanceMath.week(containing: referenceDate, records: records, expenses: expenses)
    }
    private var elapsedEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1,
                              to: Calendar.current.startOfDay(for: referenceDate)) ?? referenceDate
    }
    private var hasCurrentData: Bool {
        records.contains { $0.date >= summary.start && $0.date < elapsedEnd }
        || expenses.contains { $0.date >= summary.start && $0.date < elapsedEnd }
    }
    private var lastDay: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: summary.end) ?? summary.start
    }

    var body: some View {
        ZStack {
            CappuccinoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    balanceCard
                    if hasCurrentData {
                        chartCard
                        comparisonCard
                        dailyDetails
                    } else {
                        emptyCard
                    }
                    Text("El neto descuenta bencina y otros gastos del vehículo. Los aportes de ahorro se registran por separado.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                .frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .refreshable { referenceDate = Date() }
        }
        .foregroundStyle(Cappuccino.ink(scheme))
        .navigationTitle("Tu semana")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { referenceDate = Date() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { referenceDate = Date() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "Una mirada a tu esfuerzo")
            Text("Tu semana,\na la vista.").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
            Text("\(Cappuccino.date(summary.start)) al \(Cappuccino.date(lastDay))")
                .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
            Text("Miércoles a martes · hasta hoy, \(summary.elapsedDays) de 7 días")
                .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
        }
    }

    private var balanceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Label("Neto de la semana", systemImage: "wallet.bifold").font(.headline)
                Text(Cappuccino.money(summary.net))
                    .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    .foregroundStyle(netColor(summary.net)).monospacedDigit()
                    .minimumScaleFactor(0.65).lineLimit(1)
                    .accessibilityLabel("Neto registrado esta semana: \(Cappuccino.money(summary.net))")
                Divider()
                AmountRow(title: "Ingreso bruto", amount: summary.gross,
                          color: Cappuccino.positive(scheme))
                AmountRow(title: "Bencina", amount: summary.days.reduce(0) { $0 + $1.fuel },
                          color: Cappuccino.negative(scheme))
                AmountRow(title: "Otros gastos", amount: summary.days.reduce(0) { $0 + $1.otherExpenses },
                          color: Cappuccino.negative(scheme))
                AmountRow(title: "Total de gastos", amount: summary.expenses,
                          color: Cappuccino.negative(scheme))
            }
        }
    }

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Lo que entra y lo que sale").font(.headline)
                Text("Ingresos y gastos registrados en pesos chilenos. Los días posteriores a hoy todavía no tienen movimientos.")
                    .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                Chart {
                    ForEach(summary.days) { day in
                        BarMark(x: .value("Día", day.date, unit: .day),
                                y: .value("Pesos", day.gross))
                        .foregroundStyle(by: .value("Movimiento", "Ingresos"))
                        .position(by: .value("Movimiento", "Ingresos"))
                        BarMark(x: .value("Día", day.date, unit: .day),
                                y: .value("Pesos", day.expenses))
                        .foregroundStyle(by: .value("Movimiento", "Gastos"))
                        .position(by: .value("Movimiento", "Gastos"))
                    }
                }
                .chartForegroundStyleScale([
                    "Ingresos": Cappuccino.positive(scheme),
                    "Gastos": Cappuccino.negative(scheme)
                ])
                .chartXScale(domain: summary.start...summary.end)
                .chartXAxis {
                    AxisMarks(values: summary.days.map(\.date)) { value in
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.weekday(.abbreviated)
                                    .locale(Locale(identifier: "es_CL"))))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Cappuccino.caramel.opacity(0.16))
                        AxisValueLabel {
                            if let amount = value.as(Int.self) {
                                Text(amount.formatted(.number.notation(.compactName)
                                    .locale(Locale(identifier: "es_CL"))))
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: 14)
                .frame(height: 250)
                .accessibilityHidden(true)
                Text("Encontrarás los valores exactos en el detalle por día.")
                    .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
            }
        }
    }

    private var comparisonCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Cómo vas avanzando", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                if summary.hasPreviousData {
                    Text(summary.comparisonDelta > 0
                         ? "+\(Cappuccino.money(summary.comparisonDelta))"
                         : Cappuccino.money(summary.comparisonDelta))
                        .font(.title.weight(.bold)).fontDesign(.rounded).monospacedDigit()
                        .foregroundStyle(netColor(summary.comparisonDelta))
                    Text("Cambio del neto frente a los mismos días de la semana anterior: \(summary.elapsedDays) días en cada período.")
                        .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                    AmountRow(title: "Neto anterior comparable", amount: summary.previousComparableNet,
                              color: netColor(summary.previousComparableNet))
                    Text("La comparación usa únicamente los registros guardados de ambos períodos.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                } else {
                    Text("Todavía no hay registros de los mismos días de la semana anterior para comparar.")
                        .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                }
            }
        }
    }

    private var dailyDetails: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Detalle por día").font(.headline)
                ForEach(summary.days) { day in
                    dayRow(day)
                    if day.id != summary.days.last?.id { Divider() }
                }
            }
        }
    }

    private func dayRow(_ day: WeekDayTotal) -> some View {
        let future = Calendar.current.compare(day.date, to: referenceDate, toGranularity: .day) == .orderedDescending
        let recorded = records.contains { Calendar.current.isDate($0.date, inSameDayAs: day.date) }
            || expenses.contains { Calendar.current.isDate($0.date, inSameDayAs: day.date) }
        return VStack(alignment: .leading, spacing: 9) {
            Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)
                .locale(Locale(identifier: "es_CL"))))
                .font(.subheadline.weight(.semibold))
            if future {
                Text("Por venir").font(.caption).foregroundStyle(Cappuccino.muted(scheme))
            } else if recorded {
                AmountRow(title: "Ingresos", amount: day.gross)
                AmountRow(title: "Gastos", amount: day.expenses, color: Cappuccino.negative(scheme))
                AmountRow(title: "Neto", amount: day.net, color: netColor(day.net))
            } else {
                Text("Sin registros").font(.caption).foregroundStyle(Cappuccino.muted(scheme))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "chart.bar.xaxis").font(.title).foregroundStyle(Cappuccino.caramel)
                Text("Tu semana empieza con un registro").font(.headline)
                Text("Guarda un turno o un gasto de esta semana para ver tu gráfico. No hay movimientos registrados hasta hoy.")
                    .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
            }
        }
    }

    private func netColor(_ value: Int) -> Color {
        value > 0 ? Cappuccino.positive(scheme)
            : value < 0 ? Cappuccino.negative(scheme) : Cappuccino.muted(scheme)
    }
}
