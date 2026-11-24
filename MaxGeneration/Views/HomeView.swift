import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HeroCard()
                    DailyCheckInCard()
                    QuestsCard()
                    WeekCard()
                    TodayCard()
                    AttributesCard()
                    RecentXPCard()
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Hero")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink { BadgesView() } label: { Image(systemName: "trophy.fill") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape.fill") }
                }
            }
        }
    }
}

struct HeroCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let info = Leveling.info(store.totalXP)
        let p = store.profile
        let rank = Theme.rankColor(info.level)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Text(p.avatar)
                    .font(.system(size: 50))
                    .frame(width: 82, height: 82)
                    .background(Circle().fill(rank.opacity(0.18)))
                    .overlay(Circle().stroke(rank, lineWidth: 3))
                    .shadow(color: rank.opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name).font(.title2.bold())
                    Text("Level \(info.level) · \(Leveling.title(for: info.level))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(rank)
                    HStack(spacing: 12) {
                        Label("\(store.streak) day streak", systemImage: "flame.fill")
                            .foregroundColor(.orange)
                        Label("\(store.totalXP) XP", systemImage: "sparkles")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 6) {
                ProgressBar(value: info.fraction, color: rank, height: 12)
                HStack {
                    Text("\(info.into) / \(info.needed) XP to level \(info.level + 1)")
                    Spacer()
                    Text("+\(store.xpToday()) today")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .card()
    }
}

struct AttributesCard: View {
    @EnvironmentObject var store: Store
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats").font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Attribute.allCases) { a in
                    AttributeTile(attribute: a, info: Leveling.attributeInfo(store.xp(a)))
                }
            }
        }
        .card()
    }
}

struct AttributeTile: View {
    let attribute: Attribute
    let info: LevelInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(attribute.emoji)
                Text(attribute.short).font(.caption.bold()).foregroundColor(attribute.color)
                Spacer()
                Text("Lv \(info.level)").font(.subheadline.bold())
            }
            ProgressBar(value: info.fraction, color: attribute.color, height: 6)
            Text(attribute.blurb).font(.caption2).foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(attribute.color.opacity(0.08)))
    }
}

struct QuestsCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let quests = store.todaysQuests()
        let claimedCount = quests.filter { store.isClaimed($0) }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily Quests").font(.headline)
                Spacer()
                Text("\(claimedCount)/\(quests.count) · new ones at midnight")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if quests.isEmpty {
                Text("Turn on some areas in Settings to get quests.")
                    .foregroundColor(.secondary)
            }
            ForEach(quests) { q in
                QuestRow(quest: q)
            }
            if !quests.isEmpty {
                Text("Claim them all for a ✨ Perfect Day bonus.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .card()
    }
}

struct QuestRow: View {
    @EnvironmentObject var store: Store
    let quest: Quest

    var body: some View {
        let claimed = store.isClaimed(quest)
        HStack(spacing: 12) {
            Text(quest.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 5) {
                Text(quest.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(claimed)
                    .foregroundColor(claimed ? .secondary : .primary)
                ProgressBar(value: quest.fraction, color: quest.attribute.color, height: 6)
                Text(quest.progressText).font(.caption2).foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            if claimed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                Button {
                    store.claim(quest)
                } label: {
                    Text(quest.isDone ? "Claim +\(quest.xp)" : "+\(quest.xp) XP")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(quest.isDone ? quest.attribute.color : Color.white.opacity(0.1)))
                        .foregroundColor(quest.isDone ? .black : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!quest.isDone)
            }
        }
    }
}

struct TodayCard: View {
    @EnvironmentObject var store: Store
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        let p = store.profile
        let today = Date()
        VStack(alignment: .leading, spacing: 12) {
            Text("Today").font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                if store.has(.gym) {
                    StatTile(emoji: "🏋️", title: "Sessions this week",
                             value: "\(store.workoutsThisWeek()) / \(p.workoutsPerWeek)",
                             fraction: Double(store.workoutsThisWeek()) / Double(max(1, p.workoutsPerWeek)),
                             color: Attribute.strength.color)
                }
                if store.has(.study) {
                    let mins = store.studyMinutes(on: today)
                    StatTile(emoji: "📚", title: "Study",
                             value: "\(mins) / \(p.studyMinutesTarget) min",
                             fraction: Double(mins) / Double(max(1, p.studyMinutesTarget)),
                             color: Attribute.intellect.color)
                }
                if store.has(.food) {
                    let kcal = store.calories(on: today)
                    let prot = store.protein(on: today)
                    StatTile(emoji: "🔥", title: "Calories",
                             value: "\(kcal) / \(p.calorieTarget)",
                             fraction: Double(kcal) / Double(max(1, p.calorieTarget)),
                             color: .orange)
                    StatTile(emoji: "🥩", title: "Protein",
                             value: "\(prot) / \(p.proteinTarget) g",
                             fraction: Double(prot) / Double(max(1, p.proteinTarget)),
                             color: Attribute.vitality.color)
                }
                if store.has(.life) && !store.data.habits.isEmpty {
                    let done = store.data.habits.filter { store.isDone($0) }.count
                    StatTile(emoji: "✅", title: "Habits",
                             value: "\(done) / \(store.data.habits.count)",
                             fraction: Double(done) / Double(max(1, store.data.habits.count)),
                             color: Attribute.discipline.color)
                }
            }
        }
        .card()
    }
}

struct RecentXPCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let recent = Array(store.data.xpEvents.suffix(6).reversed())
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent XP").font(.headline)
            if recent.isEmpty {
                Text("Log anything to start earning XP.").foregroundColor(.secondary)
            }
            ForEach(recent) { e in
                HStack {
                    Circle().fill(e.attribute.color).frame(width: 8, height: 8)
                    Text(e.reason).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text("+\(e.amount)").font(.subheadline.bold()).foregroundColor(e.attribute.color)
                }
            }
        }
        .card()
    }
}
