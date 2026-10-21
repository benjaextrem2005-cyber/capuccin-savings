import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Query(sort: [SortDescriptor(\VehicleExpense.date, order: .reverse),
                  SortDescriptor(\VehicleExpense.createdAt, order: .reverse)])
    private var expenses: [VehicleExpense]
    @State private var date: Date
    @State private var amountText = ""
    @State private var category = VehicleExpense.categories.first ?? "Otros"
    @State private var note = ""
    @State private var confirmation: String?
    @State private var errorMessage: String?
    @State private var pendingDeletion: VehicleExpense?
    @State private var showAll = false

    init(initialDate: Date = Date()) {
        _date = State(initialValue: Calendar.current.startOfDay(for: min(initialDate, Date())))
    }

    private var amount: Int? { CLPAmount.parse(amountText) }
    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var valid: Bool {
        (amount ?? 0) > 0 && VehicleExpense.categories.contains(category) && note.count <= 200
    }
    private var selectedDayExpenses: [VehicleExpense] {
        expenses.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    private var selectedDayTotal: Int { selectedDayExpenses.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ZStack {
            CappuccinoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    entryCard
                    history
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                .frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Cappuccino.ink(scheme))
        .navigationTitle("Gastos del vehículo")
        .navigationBarTitleDisplayMode(.inline)
        .savingsKeyboardToolbar()
        .onChange(of: date) { _, _ in confirmation = nil }
        .onChange(of: amountText) { _, _ in clearConfirmationWhileEditing() }
        .onChange(of: category) { _, _ in clearConfirmationWhileEditing() }
        .onChange(of: note) { _, _ in clearConfirmationWhileEditing() }
        .alert("No pudimos guardar el cambio", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Entendido", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("¿Eliminar este gasto?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancelar", role: .cancel) { pendingDeletion = nil }
            Button("Eliminar", role: .destructive) { deleteExpense() }
        } message: {
            Text(pendingDeletion.map {
                "Se eliminará \($0.category.lowercased()) por \(Cappuccino.money($0.amount)) del \(Cappuccino.date($0.date))."
            } ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "El costo de seguir avanzando")
            Text("Cuida tu auto.\nCuida tu balance.")
                .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
            Text("Registra mantenciones, peajes y otros gastos. La bencina se ingresa en tu turno para evitar contarla dos veces.")
                .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
        }
    }

    private var entryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 22) {
                SectionEyebrow(title: "Nuevo gasto")
                DatePicker("Fecha del gasto", selection: $date, in: ...Date(), displayedComponents: .date)
                    .font(.subheadline.weight(.medium))
                MoneyField(title: "Monto del gasto", text: $amountText, symbol: "car.side")
                if amount == 0 {
                    Text("El gasto debe ser mayor a $0.")
                        .font(.caption).foregroundStyle(Cappuccino.negative(scheme))
                }
                Picker("Categoría", selection: $category) {
                    ForEach(VehicleExpense.categories, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .font(.subheadline.weight(.medium))
                .tint(Cappuccino.ink(scheme))
                VStack(alignment: .leading, spacing: 9) {
                    Label("Nota opcional", systemImage: "text.alignleft")
                        .font(.subheadline.weight(.medium)).foregroundStyle(Cappuccino.muted(scheme))
                    TextField("Por ejemplo, cambio de aceite", text: $note, axis: .vertical)
                        .lineLimit(2...4).textInputAutocapitalization(.sentences)
                        .padding(15)
                        .background(Cappuccino.caramel.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Nota del gasto, hasta 200 caracteres")
                    Text("\(note.count)/200 caracteres")
                        .font(.caption)
                        .foregroundStyle(note.count > 200 ? Cappuccino.negative(scheme) : Cappuccino.muted(scheme))
                    if note.count > 200 {
                        Text("Acorta la nota a un máximo de 200 caracteres para guardar.")
                            .font(.caption).foregroundStyle(Cappuccino.negative(scheme))
                    }
                }
                Divider()
                AmountRow(title: "Otros gastos de esta fecha", amount: selectedDayTotal,
                          color: Cappuccino.negative(scheme))
                Text("Puedes registrar varios gastos en un mismo día. Se descuentan del neto de esa fecha, incluso si no trabajaste.")
                    .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                Button(action: saveExpense) {
                    Label("Guardar gasto", systemImage: "checkmark.circle")
                }
                .buttonStyle(CappuccinoButtonStyle()).disabled(!valid)
                if let confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(Cappuccino.positive(scheme))
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Tus últimos gastos").font(.title3.weight(.bold)).fontDesign(.rounded)
                Spacer()
                Text("\(expenses.count)").font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Cappuccino.caramel.opacity(0.12), in: Capsule())
            }
            if expenses.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.title).foregroundStyle(Cappuccino.caramel)
                        Text("Cada gasto tiene su lugar").font(.headline)
                        Text("Guarda tu primer gasto del vehículo para ver su efecto en el balance.")
                            .font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                    }
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(expenses.prefix(showAll ? expenses.count : 7))) { expense in
                        expenseCard(expense)
                    }
                }
                if expenses.count > 7 {
                    Button(showAll ? "Mostrar solo los últimos 7 gastos" : "Ver los \(expenses.count) gastos") {
                        showAll.toggle()
                    }
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    private func expenseCard(_ expense: VehicleExpense) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(expense.category).font(.headline)
                        Text(Cappuccino.date(expense.date))
                            .font(.caption).foregroundStyle(Cappuccino.muted(scheme))
                        Text(Cappuccino.money(expense.amount))
                            .font(.title2.weight(.bold)).fontDesign(.rounded)
                            .foregroundStyle(Cappuccino.negative(scheme)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    Spacer(minLength: 0)
                    Button(role: .destructive) { pendingDeletion = expense } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Cappuccino.negative(scheme)).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Eliminar \(expense.category.lowercased()) del \(Cappuccino.date(expense.date))")
                }
                if !expense.note.isEmpty {
                    Text(expense.note).font(.subheadline).foregroundStyle(Cappuccino.muted(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func saveExpense() {
        guard valid, let amount else { return }
        let expense = VehicleExpense(date: date, amount: amount, category: category, note: trimmedNote)
        context.insert(expense)
        do {
            try context.save()
            amountText = ""
            note = ""
            category = VehicleExpense.categories.first ?? "Otros"
            confirmation = "Gasto guardado en tu balance"
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func clearConfirmationWhileEditing() {
        if !amountText.isEmpty || !note.isEmpty { confirmation = nil }
    }

    private func deleteExpense() {
        guard let expense = pendingDeletion else { return }
        context.delete(expense)
        do {
            try context.save()
            pendingDeletion = nil
            confirmation = nil
        } catch {
            context.rollback()
            pendingDeletion = nil
            errorMessage = error.localizedDescription
        }
    }
}
