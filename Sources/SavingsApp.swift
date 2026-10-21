import SwiftUI
import SwiftData

@main
@MainActor
struct SavingsApp: App {
    private let store: Result<ModelContainer, Error>
    init() {
        store = Result {
            let schema = Schema([DailyRecord.self, SavingsGoal.self, SavingsContribution.self, VehicleExpense.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            container.mainContext.autosaveEnabled = false
            return container
        }
    }
    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                ContentView().modelContainer(container).environment(\.locale, Locale(identifier: "es_CL"))
            case .failure(let error):
                ZStack {
                    CappuccinoBackground()
                    ContentUnavailableView {
                        Label("No se pudo abrir tu bitácora", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Tus datos no se han borrado. Cierra y vuelve a abrir la app.\n\n" + error.localizedDescription)
                    }
                    .padding()
                }
            }
        }
    }
}
