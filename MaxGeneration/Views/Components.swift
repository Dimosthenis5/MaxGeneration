import SwiftUI

enum Theme {
    static let accent = Color(red: 0.25, green: 0.55, blue: 1.0)
    static let bgTop = Color(red: 0.04, green: 0.07, blue: 0.2)
    static let bgBottom = Color(red: 0.02, green: 0.02, blue: 0.05)

    static func rankColor(_ level: Int) -> Color {
        switch level {
        case ..<3: return Color(red: 0.7, green: 0.7, blue: 0.75)        // stone
        case 3..<6: return Color(red: 0.45, green: 0.85, blue: 0.5)      // green
        case 6..<10: return Color(red: 0.35, green: 0.65, blue: 1.0)     // blue
        case 10..<15: return Color(red: 0.65, green: 0.45, blue: 1.0)    // purple
        case 15..<20: return Color(red: 1.0, green: 0.45, blue: 0.7)     // pink
        case 20..<30: return Color(red: 1.0, green: 0.6, blue: 0.2)      // orange
        default: return Color(red: 1.0, green: 0.82, blue: 0.25)         // gold
        }
    }
}

extension Attribute {
    var color: Color {
        switch self {
        case .strength: return Color(red: 1.0, green: 0.38, blue: 0.38)
        case .intellect: return Color(red: 0.38, green: 0.63, blue: 1.0)
        case .vitality: return Color(red: 0.3, green: 0.85, blue: 0.52)
        case .discipline: return Color(red: 1.0, green: 0.72, blue: 0.22)
        }
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }

    /// Shared look for List/Form screens.
    func gameListStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .scrollDismissesKeyboard(.interactively)
    }
}

struct ProgressBar: View {
    var value: Double
    var color: Color = Theme.accent
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.65), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: clamped <= 0 ? 0 : max(height, geo.size.width * CGFloat(clamped)))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.4), value: value)
    }
}

struct ProgressRing: View {
    var value: Double
    var color: Color
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: value)
        }
    }
}

struct StatTile: View {
    let emoji: String
    let title: String
    let value: String
    var fraction: Double? = nil
    var color: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(emoji)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            if let f = fraction {
                ProgressBar(value: f, color: color, height: 6)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 15)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color))
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(Color(red: 0.08, green: 0.15, blue: 0.4))
                    .shadow(color: Theme.accent.opacity(0.5), radius: 12)
            )
            .overlay(Capsule().stroke(Theme.accent.opacity(0.6), lineWidth: 1))
            .padding(.horizontal, 20)
    }
}

struct LevelUpOverlay: View {
    let level: Int
    let onClose: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(spacing: 14) {
                Text("LEVEL UP!")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                Text("\(level)")
                    .font(.system(size: 110, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.rankColor(level))
                    .shadow(color: Theme.rankColor(level).opacity(0.7), radius: 24)
                Text("You are now a \(Leveling.title(for: level))")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
                Button("Continue") { onClose() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 20)
                    .padding(.horizontal, 40)
            }
            .scaleEffect(appear ? 1 : 0.4)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
        }
    }
}

struct EmojiPicker: View {
    @Binding var selection: String
    let options: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options, id: \.self) { e in
                    Text(e)
                        .font(.system(size: 30))
                        .frame(width: 50, height: 50)
                        .background(
                            Circle().fill(selection == e ? Theme.accent.opacity(0.35) : Color.white.opacity(0.06))
                        )
                        .overlay(Circle().stroke(selection == e ? Theme.accent : Color.clear, lineWidth: 2))
                        .onTapGesture { selection = e }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

enum Emojis {
    static let avatars = ["🧙‍♂️", "🥷", "🦸‍♂️", "🧝", "🐉", "🦁", "🐺", "🤖", "👑", "🧑‍🚀", "🦊", "🐻", "🦅", "🧛", "🧞"]
    static let habits = ["✅", "😴", "📖", "🧘", "🥗", "🚶", "⏰", "📵", "🤸", "💧", "🧹", "💊", "🎸", "✍️", "🌅", "🚭"]
    static let bosses = ["🐉", "👹", "🧟", "🦖", "👾", "🐙", "💀", "🧌", "🦂", "🌪️"]
}
