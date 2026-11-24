import SwiftUI

/// Arcade-style "stage clear" results: rows slide in, the score tallies up, then the rank slams down.
struct ResultsView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    let result: DayScore
    let bonusXP: Int

    @State private var shownRows = 0
    @State private var displayedScore = 0
    @State private var barFill = 0.0
    @State private var showRank = false
    @State private var started = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.08, blue: 0.3), Color(red: 0.01, green: 0.02, blue: 0.1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            SpeedStripes()

            VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                banner
                    .padding(.top, 20)

                VStack(spacing: 10) {
                    ForEach(result.lines.indices, id: \.self) { i in
                        ResultRow(line: result.lines[i])
                            .opacity(i < shownRows ? 1 : 0)
                            .offset(x: i < shownRows ? 0 : 400)
                    }
                }
                .padding(.horizontal, 20)

                totalBlock
                    .padding(.horizontal, 20)
                    .opacity(shownRows >= result.lines.count ? 1 : 0)

                rankBlock
                    .padding(.vertical, 10)
            }
            }

                Button {
                    dismiss()
                } label: {
                    Text("CONTINUE")
                        .font(.system(size: 20, weight: .black, design: .rounded).italic())
                        .tracking(2)
                }
                .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.15, green: 0.4, blue: 1.0)))
                .padding(.horizontal, 30)
                .padding(.bottom, 16)
                .opacity(showRank ? 1 : 0)
            }
        }
        .onAppear { runSequence() }
    }

    private var banner: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 38, weight: .black, design: .rounded).italic())
                .foregroundColor(.white)
                .padding(.horizontal, 34)
                .padding(.vertical, 8)
                .background(Slant().fill(LinearGradient(colors: [Color(red: 1.0, green: 0.75, blue: 0.1), Color(red: 1.0, green: 0.45, blue: 0.1)],
                                                         startPoint: .leading, endPoint: .trailing)))
                .shadow(color: .orange.opacity(0.6), radius: 12)
            Text(subtitle.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(3)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var totalBlock: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TOTAL")
                    .font(.system(size: 22, weight: .black, design: .rounded).italic())
                Spacer()
                Text("\(displayedScore)")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(Rank.color(Rank.rank(for: displayedScore)))
                Text("/ 100")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.6))
            }
            ProgressBar(value: barFill, color: Rank.color(Rank.rank(for: displayedScore)), height: 16)
        }
        .padding(14)
        .background(Slant(skew: 14).fill(Color.white.opacity(0.08)))
    }

    private var rankBlock: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Rank.color(result.rank).opacity(0.18))
                    .frame(width: 150, height: 150)
                Circle()
                    .stroke(Rank.color(result.rank), lineWidth: 6)
                    .frame(width: 150, height: 150)
                Text(result.rank)
                    .font(.system(size: result.rank.count > 1 ? 76 : 96, weight: .black, design: .rounded).italic())
                    .foregroundColor(Rank.color(result.rank))
                    .shadow(color: Rank.color(result.rank).opacity(0.9), radius: 20)
            }
            .scaleEffect(showRank ? 1 : 3)
            .opacity(showRank ? 1 : 0)
            .rotationEffect(.degrees(showRank ? -8 : -30))

            Text(Rank.message(result.rank))
                .font(.headline)
                .foregroundColor(.white)
                .opacity(showRank ? 1 : 0)
            Text("+\(bonusXP) XP rank bonus")
                .font(.subheadline.bold())
                .foregroundColor(Theme.accent)
                .opacity(showRank ? 1 : 0)
        }
    }

    private func runSequence() {
        guard !started else { return }
        started = true
        Task { @MainActor in
            for i in 0..<result.lines.count {
                try? await Task.sleep(nanoseconds: 230_000_000)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { shownRows = i + 1 }
                SoundFX.play(.tick)
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeOut(duration: 1.2)) { barFill = Double(result.score) / 100 }
            let steps = 24
            for s in 1...steps {
                displayedScore = Int((Double(result.score) * Double(s) / Double(steps)).rounded())
                if s % 2 == 0 { SoundFX.play(.tick) }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { showRank = true }
            SoundFX.play(.rank)
            Haptics.heavy()
        }
    }
}

struct ResultRow: View {
    let line: ScoreLine

    var body: some View {
        HStack(spacing: 10) {
            Text(line.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.title.uppercased())
                    .font(.system(size: 15, weight: .heavy, design: .rounded).italic())
                    .foregroundColor(.white)
                Text(line.detail)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            Text("\(line.points)")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(line.fraction >= 1 ? Color(red: 1.0, green: 0.84, blue: 0.2) : .white)
            Text("/\(Int(line.weight))")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Slant(skew: 12).fill(Color.white.opacity(0.07)))
    }
}

/// Parallelogram, for banners and rows.
struct Slant: Shape {
    var skew: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + skew, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - skew, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct SpeedStripes: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 3 == 0 ? 0.05 : 0.02))
                        .frame(width: CGFloat(14 + (i % 4) * 10), height: geo.size.height * 2)
                        .rotationEffect(.degrees(24))
                        .offset(x: CGFloat(i) * geo.size.width / 8 - geo.size.width / 2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
