import SwiftUI

enum Cappuccino {
    static let caramel = Color(red: 0.73, green: 0.48, blue: 0.25)
    static let gold = Color(red: 0.88, green: 0.69, blue: 0.43)
    static let espresso = Color(red: 0.20, green: 0.13, blue: 0.10)
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.89)
    static func ink(_ scheme: ColorScheme) -> Color { scheme == .dark ? cream : espresso }
    static func muted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.77, green: 0.70, blue: 0.62) : Color(red: 0.43, green: 0.36, blue: 0.31)
    }
    static func positive(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.49, green: 0.83, blue: 0.68) : Color(red: 0.13, green: 0.40, blue: 0.30)
    }
    static func negative(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.96, green: 0.61, blue: 0.48) : Color(red: 0.66, green: 0.25, blue: 0.17)
    }
    static func money(_ amount: Int) -> String {
        amount.formatted(.currency(code: "CLP").precision(.fractionLength(0)).locale(Locale(identifier: "es_CL")))
    }
    static func date(_ value: Date) -> String {
        value.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_CL")))
    }
}

struct CappuccinoBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: scheme == .dark
                               ? [Color(red: 0.14, green: 0.10, blue: 0.09), Color(red: 0.24, green: 0.18, blue: 0.14)]
                               : [Cappuccino.cream, Color(red: 0.90, green: 0.84, blue: 0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Cappuccino.gold.opacity(scheme == .dark ? 0.16 : 0.28), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: geometry.size.width)
                Circle().fill(Cappuccino.caramel.opacity(0.10))
                    .frame(width: 280, height: 280).blur(radius: 65)
                    .offset(x: -geometry.size.width / 2, y: 160)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(scheme == .dark ? Cappuccino.espresso : Cappuccino.cream)
                } else {
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill((scheme == .dark ? Cappuccino.espresso : Cappuccino.cream).opacity(0.28))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Cappuccino.gold.opacity(0.50), .white.opacity(0.08)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: Cappuccino.espresso.opacity(scheme == .dark ? 0.12 : 0.05), radius: 18, x: 0, y: 8)
    }
}

struct CappuccinoButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(Cappuccino.cream)
            .background(LinearGradient(colors: [Cappuccino.espresso, Color(red: 0.38, green: 0.25, blue: 0.16)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(Cappuccino.gold.opacity(0.55), lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.80 : 1) : 0.45)
    }
}

struct MoneyField: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    @Binding var text: String
    let symbol: String
    private var invalid: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && CLPAmount.parse(text) == nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.medium))
                .foregroundStyle(Cappuccino.muted(scheme))
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("$").foregroundStyle(Cappuccino.caramel)
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .accessibilityLabel(title + ", pesos chilenos")
            }
            .font(.title2.weight(.semibold))
            .padding(15)
            .background(Cappuccino.caramel.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(invalid ? Cappuccino.negative(scheme) : Cappuccino.caramel.opacity(0.18), lineWidth: 1))
            if invalid {
                Text("Ingresa pesos enteros entre $0 y $999.999.999; por ejemplo, 25.000.")
                    .font(.caption).foregroundStyle(Cappuccino.negative(scheme))
            }
        }
    }
}

struct SectionEyebrow: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    var body: some View {
        Text(title.uppercased()).font(.caption.weight(.bold)).tracking(2)
            .foregroundStyle(Cappuccino.muted(scheme))
    }
}

struct AmountRow: View {
    let title: String
    let amount: Int
    var color: Color = .primary
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { Text(title); Spacer(minLength: 12); Text(Cappuccino.money(amount)).fontWeight(.semibold).foregroundStyle(color) }
            VStack(alignment: .leading, spacing: 4) { Text(title); Text(Cappuccino.money(amount)).fontWeight(.semibold).foregroundStyle(color) }
        }
        .font(.subheadline).monospacedDigit()
    }
}
