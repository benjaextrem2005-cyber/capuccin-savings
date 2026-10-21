import SwiftUI
import SwiftData

struct GoalCalculatorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \SavingsGoal.updatedAt, order: .reverse) private var goals: [SavingsGoal]
    @Query(sort: \SavingsContribution.date, order: .reverse) private var contributions: [SavingsContribution]
    @State private var name = "Mi próxima meta"
    @State private var targetText = ""
    @State private var fuelText = ""
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var months = 3
    @State private var daysPerWeek = 5
    @State private var loaded = false
    @State private var showGoalConfiguration = false
    @State private var contributionTarget: ContributionSheetTarget?
    @State private var contributionToDelete: ContributionDeletion?
    @State private var confirmation: String?
    @State private var errorMessage: String?

    private var goal: SavingsGoal? { goals.first }
    private var goalContributions: [SavingsContribution] {
        guard let goal else { return [] }
        return contributions.filter { $0.goalID == goal.id }
    }
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
                    if let goal {
                        progressCard(for: goal)
                        DailyTargetCard()
                        contributionHistory
                        DisclosureGroup(isExpanded: $showGoalConfiguration) {
                            configuration.padding(.top, 18)
                        } label: {
                            Label("Configurar mi meta", systemImage: "slider.horizontal.3")
                                .font(.headline).padding(.vertical, 12)
                        }
                        .tint(Cappuccino.ink(scheme))
                    } else {
                        GlassCard {
                            Text("Guarda tu meta para registrar el dinero que apartes y seguir tu avance real.")
                                .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                        }
                        configuration
                    }
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
        .sheet(item: $contributionTarget) { target in
            ContributionEntrySheet(goalID: target.id, goalName: target.name)
        }
        .alert("No pudimos guardar el cambio", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("¿Eliminar este aporte?", isPresented: Binding(get: { contributionToDelete != nil }, set: { if !$0 { contributionToDelete = nil } })) {
            Button("Cancelar", role: .cancel) { contributionToDelete = nil }
            Button("Eliminar", role: .destructive) { deleteContribution() }
        } message: {
            if let contributionToDelete {
                Text("Se quitarán \(Cappuccino.money(contributionToDelete.amount)) del ahorro registrado del \(Cappuccino.date(contributionToDelete.date)).")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "Un destino para tu esfuerzo")
            Text("Lo que apartas,\nse acerca.").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
            Text("Una cosa es ganar dinero. Otra es guardarlo para tu meta.")
                .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
        }
    }

    private func progressCard(for goal: SavingsGoal) -> some View {
        let progress = FinanceMath.progress(goal: goal, contributions: goalContributions)
        return GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionEyebrow(title: "Ahorro que sí apartaste")
                Text(goal.name).font(.title2.weight(.bold)).fontDesign(.rounded)
                Text(Cappuccino.money(progress.saved))
                    .font(.largeTitle.weight(.bold)).fontDesign(.rounded).monospacedDigit()
                    .minimumScaleFactor(0.65).lineLimit(1)
                    .foregroundStyle(Cappuccino.positive(scheme))
                ProgressView(value: min(1, max(0, progress.fraction)))
                    .tint(Cappuccino.positive(scheme))
                    .accessibilityLabel("Avance de tu meta")
                    .accessibilityValue(progress.fraction.formatted(.percent.precision(.fractionLength(0))))
                AmountRow(title: "Objetivo", amount: goal.targetAmount)
                AmountRow(title: "Te falta ahorrar", amount: progress.remaining)
                if progress.remaining == 0 {
                    Label("Meta cumplida", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(Cappuccino.positive(scheme))
                    if progress.saved > goal.targetAmount {
                        AmountRow(title: "Por encima de tu meta", amount: progress.saved - goal.targetAmount,
                                  color: Cappuccino.positive(scheme))
                    }
                } else {
                    Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Cappuccino.muted(scheme))
                }
                Button {
                    contributionTarget = ContributionSheetTarget(id: goal.id, name: goal.name)
                } label: {
                    Label("Aparté dinero", systemImage: "plus.circle.fill")
                }
                .buttonStyle(CappuccinoButtonStyle())
                Text("Registra solo dinero que ya separaste. Guardar un turno no aumenta este ahorro automáticamente.")
                    .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
            }
        }
    }

    private var contributionHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tus aportes").font(.title3.weight(.bold)).fontDesign(.rounded)
            if goalContributions.isEmpty {
                GlassCard {
                    Text("Tu primer aporte aparecerá aquí cuando registres dinero con «Aparté dinero».")
                        .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(goalContributions) { contribution in
                        GlassCard {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(Cappuccino.date(contribution.date)).font(.subheadline)
                                    Text(Cappuccino.money(contribution.amount))
                                        .font(.title3.weight(.semibold)).monospacedDigit()
                                        .foregroundStyle(Cappuccino.positive(scheme))
                                }
                                Spacer(minLength: 8)
                                Button(role: .destructive) {
                                    contributionToDelete = ContributionDeletion(id: contribution.id, date: contribution.date, amount: contribution.amount)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Cappuccino.negative(scheme)).frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Eliminar aporte de \(Cappuccino.money(contribution.amount)) del \(Cappuccino.date(contribution.date))")
                            }
                        }
                    }
                }
            }
        }
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 22) {
            goalDetails
            schedule
            projection
            Button(action: saveGoal) {
                Label(goal == nil ? "Guardar mi meta" : "Actualizar mi meta", systemImage: "bookmark")
            }
            .buttonStyle(CappuccinoButtonStyle()).disabled(!valid)
            if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(.subheadline).foregroundStyle(Cappuccino.positive(scheme))
            }
            Text("La proyección inicial reparte el objetivo entre los días del plazo. Tu objetivo de cada turno se ajusta con los aportes reales y los días restantes. Actualizar la meta conserva tus aportes.")
                .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
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
                        Text(months == 1 ? "1 mes" : "\(months) meses").font(.headline)
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
                Label("Proyección inicial del plazo", systemImage: "sun.horizon").font(.headline)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(workdays)").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    Text("días de trabajo").font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                }
                if let plan {
                    Text("Hasta el \(Cappuccino.date(plan.endDate)) · fecha de término no incluida")
                        .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                    Divider()
                    AmountRow(title: "Ahorro diario inicial", amount: plan.dailySavings, color: Cappuccino.positive(scheme))
                    AmountRow(title: "+ Bencina diaria estimada", amount: fuel ?? 0, color: Cappuccino.negative(scheme))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bruto mínimo diario inicial").font(.subheadline.weight(.medium))
                        Text(Cappuccino.money(plan.minimumDailyGross)).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                            .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                        Text("Ahorro requerido + bencina").font(.caption)
                    }
                    .foregroundStyle(Cappuccino.ink(scheme))
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Cappuccino.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 20))
                    Text("El ahorro diario se redondea hacia arriba al peso. Esta proyección no incluye otros gastos del vehículo.")
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
            showGoalConfiguration = true
            confirmation = "Tu meta está guardada en este iPhone"
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteContribution() {
        guard let pending = contributionToDelete else { return }
        contributionToDelete = nil
        do {
            let id = pending.id
            var query = FetchDescriptor<SavingsContribution>(predicate: #Predicate { $0.id == id })
            query.fetchLimit = 1
            if let contribution = try context.fetch(query).first {
                context.delete(contribution)
                try context.save()
            }
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct ContributionSheetTarget: Identifiable {
    let id: UUID
    let name: String
}

private struct ContributionDeletion {
    let id: UUID
    let date: Date
    let amount: Int
}

private struct ContributionEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let goalID: UUID
    let goalName: String
    @State private var date = Date()
    @State private var amountText = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var amount: Int? { CLPAmount.parse(amountText) }
    private var valid: Bool {
        (amount ?? 0) > 0 && Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CappuccinoBackground()
                ScrollView {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 22) {
                            Text(goalName).font(.title2.weight(.bold)).fontDesign(.rounded)
                            Text("¿Cuánto dinero separaste para esta meta?")
                                .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                            DatePicker("Fecha del aporte", selection: $date, in: ...Date(), displayedComponents: .date)
                            MoneyField(title: "Dinero que apartaste", text: $amountText, symbol: "banknote")
                            Text("Esto registra un aporte real declarado por ti; no mueve dinero desde tu banco ni desde Uber.")
                                .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                            Button(action: saveContribution) {
                                Label("Guardar aporte", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(CappuccinoButtonStyle()).disabled(!valid || isSaving)
                        }
                    }
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .foregroundStyle(Cappuccino.ink(scheme))
            .navigationTitle("Aparté dinero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.frame(minHeight: 44)
                }
            }
            .savingsKeyboardToolbar()
            .alert("No pudimos guardar el aporte", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Entendido", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .presentationDragIndicator(.visible)
    }

    private func saveContribution() {
        guard valid, !isSaving, let amount else { return }
        isSaving = true
        do {
            let savedGoalID = goalID
            var query = FetchDescriptor<SavingsGoal>(predicate: #Predicate { $0.id == savedGoalID })
            query.fetchLimit = 1
            guard try context.fetch(query).first != nil else {
                errorMessage = "Guarda tu meta antes de registrar un aporte."
                isSaving = false
                return
            }
            context.insert(SavingsContribution(goalID: goalID, date: date, amount: amount))
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}
