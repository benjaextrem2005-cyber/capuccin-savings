import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        TabView {
            NavigationStack { DailyEntryView() }
                .tabItem { Label("Registro", systemImage: "chart.bar.doc.horizontal") }
            NavigationStack { GoalCalculatorView() }
                .tabItem { Label("Mi meta", systemImage: "target") }
            NavigationStack { ExpensesView() }
                .tabItem { Label("Gastos", systemImage: "wrench.and.screwdriver") }
            NavigationStack { WeeklySummaryView() }
                .tabItem { Label("Semana", systemImage: "chart.bar.xaxis") }
        }
        .tint(scheme == .dark ? Cappuccino.gold : Cappuccino.espresso)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

extension View {
    func savingsKeyboardToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
