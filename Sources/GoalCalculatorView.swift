import SwiftUI
import SwiftData

struct GoalCalculatorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \SavingsGoal.updatedAt, order: .reverse) private var goals: [SavingsGoal]
    @State private var name = "Mi próxima meta"
    @State private var targetText = ""
    @State private var fuelText = ""
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var months = 3
    @State private var daysPerWeek = 5
    @State private var loaded = false
    @State private var confirmation: String?
    @State private var errorMessage: String?

    private var target: Int? { CLPAmount.parse(targetText) }
    private var fuel: Int? { CLPAmount.parse(fuelText) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var workdays: Int { SavingsMath.workdays(start: startDate, months: months, daysPerWeek: daysPerWeek) }
    private var plan: GoalPlan? {
        guard let target, let fuel else { return nil }
        return SavingsMath.plan(targetAmount: target, start: startDate, months: months, daysPerWeek: daysPerWeek, dailyFuelEstimate: fuel)
    }
    private var valid: Bool { plan != nil && !trimmedName.isEmpty && trimmedName.count <= 80 }
    private var weekdayDescription: String {
        switch daysPerWeek {
        case 1: return "Miércoles"
        case 2: return "Miércoles y jueves"
        case 3: return "Miércoles a viernes"
        case 4: return "Miércoles a sábado"
        case 5: return "Miércoles a domingo · descanso lunes y martes"
        case 6: return "Miércoles a lunes · descanso martes"
        default: return "Todos los días"
        }
    }

    var body: some View {
        ZStack {
            CappuccinoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    goalDetails
                    schedule
                    projection
                    Button(action: saveGoal) {
                        Label(goals.isEmpty ? "Guardar mi meta" : "Actualizar mi meta", systemImage: "bookmark")
                    }
                    .buttonStyle(CappuccinoButtonStyle()).disabled(!valid)
                    if let confirmation {
                        Label(confirmation, systemImage: "checkmark.circle.fill")
                            .font(.subheadline).foregroundStyle(Cappuccino.positive(scheme))
                    }
                    Text("Esta proyección supone que reservas todo el neto después de bencina para tu meta. No descuenta gastos personales ni mantenimiento y no registra transferencias reales de ahorro.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                .frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Cappuccino.ink(scheme))
        .navigationTitle("Mi meta")
        .navigationBarTitleDisplayMode(.inline)
        .savingsKeyboardToolbar()
        .task { loadGoal() }
        .onChange(of: name) { _, _ in confirmation = nil }
        .onChange(of: targetText) { _, _ in confirmation = nil }
        .onChange(of: fuelText) { _, _ in confirmation = nil }
        .onChange(of: startDate) { _, _ in confirmation = nil }
        .onChange(of: months) { _, _ in confirmation = nil }
        .onChange(of: daysPerWeek) { _, _ in confirmation = nil }
        .alert("No pudimos guardar tu meta", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "Un destino para tu esfuerzo")
            Text("Haz espacio para\nlo que viene.").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
            Text("Transforma una meta grande en un plan para cada turno.")
                .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
        }
    }

    private var goalDetails: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 22) {
                SectionEyebrow(title: "Tu objetivo")
                VStack(alignment: .leading, spacing: 9) {
                    Label("Nombre de la meta", systemImage: "flag").font(.subheadline.weight(.medium))
                        .foregroundStyle(Cappuccino.muted(scheme))
                    TextField("Por ejemplo, renovar mi auto", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .font(.headline).padding(15)
                        .background(Cappuccino.caramel.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Nombre de la meta")
                    if trimmedName.count > 80 {
                        Text("Usa un nombre de hasta 80 caracteres.").font(.caption).foregroundStyle(Cappuccino.negative(scheme))
                    }
                }
                MoneyField(title: "Monto que quieres ahorrar", text: $targetText, symbol: "target")
                MoneyField(title: "Bencina estimada por día", text: $fuelText, symbol: "fuelpump")
                Text("Puedes ingresar $0 si no quieres incluir bencina en la proyección.")
                    .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
            }
        }
    }

    private var schedule: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 22) {
                SectionEyebrow(title: "A tu ritmo")
                DatePicker("Fecha de inicio", selection: $startDate, displayedComponents: .date)
                    .font(.subheadline.weight(.medium))
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Plazo").font(.headline)
                        Spacer()
                        Text(months == 1 ? "1 mes" : "\(months) meses").font(.headline).foregroundStyle(Cappuccino.caramel)
                    }
                    Slider(value: Binding(get: { Double(months) }, set: { months = Int($0) }), in: 1...12, step: 1)
                        .tint(Cappuccino.caramel)
                        .accessibilityLabel("Plazo en meses").accessibilityValue("\(months)")
                    HStack { Text("1 mes"); Spacer(); Text("12 meses") }
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                }
                Divider()
                Stepper(value: $daysPerWeek, in: 1...7) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(daysPerWeek) días por semana").font(.headline)
                        Text(weekdayDescription).font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                    }
                }
                Text("La semana laboral comienza el miércoles. Contamos fechas reales desde el inicio, incluido, hasta el término, sin incluirlo. No se descuentan feriados.")
                    .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
            }
        }
    }

    private var projection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Label("Tu plan diario", systemImage: "sun.horizon").font(.headline)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(workdays)").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    Text("días de trabajo").font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                }
                if let plan {
                    Text("Hasta el \(Cappuccino.date(plan.endDate)) · fecha de término no incluida")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                    Divider()
                    AmountRow(title: "Ahorro diario requerido", amount: plan.dailySavings, color: Cappuccino.positive(scheme))
                    AmountRow(title: "+ Bencina diaria estimada", amount: fuel ?? 0, color: Cappuccino.negative(scheme))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bruto mínimo diario").font(.subheadline.weight(.medium))
                        Text(Cappuccino.money(plan.minimumDailyGross)).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                            .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                        Text("Ahorro requerido + bencina").font(.caption)
                    }
                    .foregroundStyle(Cappuccino.ink(scheme))
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Cappuccino.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 20))
                    Text("El ahorro diario se redondea hacia arriba al peso para cubrir el objetivo.")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                } else {
                    Text("Ingresa una meta mayor a $0 y tu bencina diaria para ver cuánto necesitas generar por turno.")
                        .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                }
            }
        }
    }

    private func loadGoal() {
        guard !loaded else { return }
        loaded = true
        guard let goal = goals.first else { return }
        name = goal.name
        targetText = String(goal.targetAmount)
        fuelText = String(goal.dailyFuelEstimate)
        startDate = goal.startDate
        months = min(12, max(1, goal.months))
        daysPerWeek = min(7, max(1, goal.daysPerWeek))
    }

    private func saveGoal() {
        guard valid, let target, let fuel else { return }
        do {
            var query = FetchDescriptor<SavingsGoal>(sortBy: [SortDescriptor(\SavingsGoal.updatedAt, order: .reverse)])
            query.fetchLimit = 1
            if let goal = try context.fetch(query).first {
                goal.name = trimmedName
                goal.targetAmount = target
                goal.dailyFuelEstimate = fuel
                goal.startDate = Calendar.current.startOfDay(for: startDate)
                goal.months = months
                goal.daysPerWeek = daysPerWeek
                goal.updatedAt = Date()
            } else {
                context.insert(SavingsGoal(name: trimmedName, targetAmount: target, startDate: startDate, months: months,
                                           daysPerWeek: daysPerWeek, dailyFuelEstimate: fuel))
            }
            try context.save()
            confirmation = "Tu meta está guardada en este iPhone"
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
