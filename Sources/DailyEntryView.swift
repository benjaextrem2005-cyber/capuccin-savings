import SwiftUI
import SwiftData

struct DailyEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \DailyRecord.date, order: .reverse) private var records: [DailyRecord]
    @Query(sort: \VehicleExpense.date, order: .reverse) private var expenses: [VehicleExpense]
    @State private var date = Date()
    @State private var incomeText = ""
    @State private var fuelText = ""
    @State private var confirmation: String?
    @State private var errorMessage: String?
    @State private var pendingDeletion: DailyRecord?
    @State private var showAll = false
    @State private var loaded = false

    private var income: Int? { CLPAmount.parse(incomeText) }
    private var fuel: Int? { CLPAmount.parse(fuelText) }
    private var selectedOtherExpenses: Int { FinanceMath.day(date, records: [], expenses: expenses).otherExpenses }
    private var net: Int { (income ?? 0) - (fuel ?? 0) - selectedOtherExpenses }
    private var isValid: Bool { income != nil && fuel != nil }
    private var existing: DailyRecord? { records.first { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private var monthRecords: [DailyRecord] { records.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) } }
    private var monthOtherExpenses: Int {
        expenses.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }
    private var monthNet: Int { monthRecords.reduce(0) { $0 + $1.netIncome } - monthOtherExpenses }

    var body: some View {
        ZStack {
            CappuccinoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    monthSummary
                    DailyTargetCard()
                    entryCard
                    history
                    Text("El saldo descuenta bencina y los otros gastos que registres. Apartar dinero para tu meta no se descuenta otra vez como gasto.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Cappuccino.ink(scheme))
        .navigationTitle("Cappuccino")
        .navigationBarTitleDisplayMode(.inline)
        .savingsKeyboardToolbar()
        .task {
            guard !loaded else { return }
            loaded = true
            loadSelectedDay()
        }
        .onChange(of: date) { _, _ in loadSelectedDay() }
        .onChange(of: incomeText) { _, _ in confirmation = nil }
        .onChange(of: fuelText) { _, _ in confirmation = nil }
        .alert("No pudimos guardar el cambio", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("¿Eliminar este registro?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Cancelar", role: .cancel) { pendingDeletion = nil }
            Button("Eliminar", role: .destructive) { deleteSelectedRecord() }
        } message: {
            Text(pendingDeletion.map { "Se eliminarán los ingresos y la bencina del \(Cappuccino.date($0.date)). Los otros gastos de esa fecha se conservan en Gastos." } ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "Tu turno, en claro")
            Text("Cada turno cuenta.").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
            Text("Registra lo que ganaste. Descubre lo que queda.")
                .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
        }
        .accessibilityElement(children: .combine)
    }

    private var monthSummary: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("Balance del mes", systemImage: "sparkles").font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(monthRecords.count) días").font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                Text(Cappuccino.money(monthNet)).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    .foregroundStyle(monthNet >= 0 ? Cappuccino.positive(scheme) : Cappuccino.negative(scheme))
                    .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                    .accessibilityLabel("Neto del mes: \(Cappuccino.money(monthNet))")
                Divider().overlay(Cappuccino.gold.opacity(0.2))
                AmountRow(title: "Ingresos registrados", amount: monthRecords.reduce(0) { $0 + $1.grossIncome })
                AmountRow(title: "Bencina registrada", amount: monthRecords.reduce(0) { $0 + $1.fuelExpense }, color: Cappuccino.negative(scheme))
                AmountRow(title: "Otros gastos registrados", amount: monthOtherExpenses, color: Cappuccino.negative(scheme))
            }
        }
    }

    private var entryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 22) {
                SectionEyebrow(title: existing == nil ? "Nuevo registro" : "Editar registro")
                DatePicker("Fecha del turno", selection: $date, in: ...Date(), displayedComponents: .date)
                    .font(.subheadline.weight(.medium))
                MoneyField(title: "Ingreso bruto · Uber", text: $incomeText, symbol: "arrow.down.left.circle")
                MoneyField(title: "Gasto de bencina", text: $fuelText, symbol: "fuelpump")
                AmountRow(title: "Otros gastos de esta fecha", amount: selectedOtherExpenses, color: Cappuccino.negative(scheme))
                NavigationLink {
                    ExpensesView(initialDate: date)
                } label: {
                    Label("Agregar o revisar otros gastos", systemImage: "wrench.and.screwdriver")
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("Ganancia neta diaria").font(.subheadline)
                    Text(Cappuccino.money(net)).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                        .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                        .foregroundStyle(net >= 0 ? Cappuccino.positive(scheme) : Cappuccino.negative(scheme))
                    Text("Ingreso bruto − bencina − otros gastos").font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background((net >= 0 ? Cappuccino.positive(scheme) : Cappuccino.negative(scheme)).opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                if existing != nil {
                    Text("Ya hay un registro para esta fecha. Al guardar se actualizará; no se duplicará.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                Button(action: saveRecord) {
                    Label(existing == nil ? "Guardar turno" : "Actualizar registro", systemImage: "checkmark.circle")
                }
                .buttonStyle(CappuccinoButtonStyle()).disabled(!isValid)
                if let confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(Cappuccino.positive(scheme))
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Tus últimos días").font(.title3.weight(.bold)).fontDesign(.rounded)
                Spacer()
                Text("\(records.count)").font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Cappuccino.caramel.opacity(0.12), in: Capsule())
            }
            if records.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "book.closed").font(.title).foregroundStyle(Cappuccino.caramel)
                        Text("Aquí empieza tu bitácora").font(.headline)
                        Text("Guarda tu primer turno para ver tus ingresos, gastos y neto de cada día.")
                            .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                    }
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(records.prefix(showAll ? records.count : 7))) { record in
                        recordCard(record)
                    }
                }
                if records.count > 7 {
                    Button(showAll ? "Mostrar solo los últimos 7 días" : "Ver los \(records.count) registros") { showAll.toggle() }
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    private func recordCard(_ record: DailyRecord) -> some View {
        let totals = FinanceMath.day(record.date, records: [record], expenses: expenses)
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(Cappuccino.date(record.date)).font(.headline)
                        Text(Cappuccino.money(totals.net)).font(.title2.weight(.bold)).fontDesign(.rounded)
                            .foregroundStyle(totals.net >= 0 ? Cappuccino.positive(scheme) : Cappuccino.negative(scheme))
                    }
                    Spacer(minLength: 8)
                    Button { date = record.date; loadSelectedDay() } label: {
                        Image(systemName: "pencil").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Editar registro del \(Cappuccino.date(record.date))")
                    Button(role: .destructive) { pendingDeletion = record } label: {
                        Image(systemName: "trash").foregroundStyle(Cappuccino.negative(scheme)).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Eliminar registro del \(Cappuccino.date(record.date))")
                }
                AmountRow(title: "Ingreso bruto", amount: record.grossIncome)
                AmountRow(title: "Bencina", amount: record.fuelExpense, color: Cappuccino.negative(scheme))
                if totals.otherExpenses > 0 {
                    AmountRow(title: "Otros gastos", amount: totals.otherExpenses, color: Cappuccino.negative(scheme))
                }
            }
        }
    }

    private func loadSelectedDay() {
        if let record = existing {
            incomeText = String(record.grossIncome)
            fuelText = String(record.fuelExpense)
        } else {
            incomeText = ""
            fuelText = ""
        }
        confirmation = nil
    }

    private func saveRecord() {
        guard let income, let fuel else { return }
        do {
            let day = Calendar.current.startOfDay(for: date)
            var query = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.date == day })
            query.fetchLimit = 1
            let storedRecord = try context.fetch(query).first
            if let record = storedRecord {
                record.grossIncome = income
                record.fuelExpense = fuel
            } else {
                context.insert(DailyRecord(date: day, grossIncome: income, fuelExpense: fuel))
            }
            try context.save()
            confirmation = storedRecord != nil ? "Registro actualizado" : "Turno guardado en tu bitácora"
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelectedRecord() {
        guard let record = pendingDeletion else { return }
        let deletingSelectedDay = Calendar.current.isDate(record.date, inSameDayAs: date)
        context.delete(record)
        do {
            try context.save()
            pendingDeletion = nil
            if deletingSelectedDay {
                incomeText = ""
                fuelText = ""
                confirmation = nil
            }
        } catch {
            context.rollback()
            pendingDeletion = nil
            errorMessage = error.localizedDescription
        }
    }
}
