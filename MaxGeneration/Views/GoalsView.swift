import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var store: Store
    @State private var showAddHabit = false
    @State private var showAddBoss = false
    @State private var attackTarget: Boss? = nil
    @State private var showAttack = false
    @State private var attackAmount = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.data.habits.isEmpty {
                        Text("No habits yet. Add one below.").foregroundColor(.secondary)
                    }
                    ForEach(store.data.habits) { h in
                        HabitRow(habit: h)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.data.habits[$0].id }
                        for id in ids { store.deleteHabit(id) }
                    }
                    Button {
                        showAddHabit = true
                    } label: {
                        Label("Add habit", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Daily habits · +10 XP each")
                }

                Section {
                    if store.activeBosses.isEmpty {
                        Text("Turn a big goal into a boss: \"Read 12 books\", \"Lose 5 kg\", \"Save €1000\". Every bit of progress deals damage.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    ForEach(store.activeBosses) { b in
                        BossCard(boss: b) {
                            attackTarget = b
                            attackAmount = ""
                            showAttack = true
                        }
                    }
                    .onDelete { offsets in
                        let bosses = store.activeBosses
                        let ids = offsets.map { bosses[$0].id }
                        for id in ids { store.deleteBoss(id) }
                    }
                    Button {
                        showAddBoss = true
                    } label: {
                        Label("Summon a boss", systemImage: "flame.circle.fill")
                    }
                } header: {
                    Text("Boss battles · big goals")
                }

                if !store.defeatedBosses.isEmpty {
                    Section("Hall of fame") {
                        ForEach(store.defeatedBosses) { b in
                            HStack {
                                Text(b.emoji).font(.title2).grayscale(1)
                                VStack(alignment: .leading) {
                                    Text(b.name).strikethrough()
                                    if let d = b.defeatedAt {
                                        Text("Defeated \(d.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("🏆")
                            }
                        }
                        .onDelete { offsets in
                            let bosses = store.defeatedBosses
                            let ids = offsets.map { bosses[$0].id }
                            for id in ids { store.deleteBoss(id) }
                        }
                    }
                }
            }
            .gameListStyle()
            .navigationTitle("Goals")
            .sheet(isPresented: $showAddHabit) {
                AddHabitSheet().environmentObject(store)
            }
            .sheet(isPresented: $showAddBoss) {
                AddBossSheet().environmentObject(store)
            }
            .alert("Deal damage", isPresented: $showAttack, presenting: attackTarget) { boss in
                TextField("Amount", text: $attackAmount)
                    .keyboardType(.decimalPad)
                Button("Attack! ⚔️") {
                    if let amount = Num.parse(attackAmount), amount > 0 {
                        store.hit(boss, amount: amount)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { boss in
                Text("How much progress did you make on \"\(boss.name)\"? (\(boss.unit))")
            }
        }
    }
}

struct HabitRow: View {
    @EnvironmentObject var store: Store
    let habit: Habit

    var body: some View {
        let done = store.isDone(habit)
        let streak = Streaks.current(habit.completions)
        Button {
            store.toggle(habit)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(done ? habit.attribute.color : .secondary)
                Text(habit.emoji).font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    weekDots
                }
                Spacer()
                if streak > 0 {
                    Text("🔥 \(streak)")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var weekDots: some View {
        let cal = Calendar.current
        let days: [Date] = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
        return HStack(spacing: 4) {
            ForEach(days, id: \.self) { d in
                Circle()
                    .fill(habit.completions.contains(Day.key(d)) ? habit.attribute.color : Color.white.opacity(0.12))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct BossCard: View {
    let boss: Boss
    let onAttack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(boss.emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text(boss.name).font(.headline)
                    Text("\(boss.attribute.emoji) \(boss.attribute.title) boss")
                        .font(.caption)
                        .foregroundColor(boss.attribute.color)
                    if let deadline = boss.deadline {
                        Text(deadlineText(deadline))
                            .font(.caption2)
                            .foregroundColor(deadline < Date() ? .red : .secondary)
                    }
                }
                Spacer()
                Button(action: onAttack) {
                    Text("Attack")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderless)
            }
            VStack(alignment: .leading, spacing: 4) {
                ProgressBar(value: 1 - boss.progress, color: .red, height: 12)
                HStack {
                    Text("HP \(Num.text(boss.hpLeft)) / \(Num.text(boss.target)) \(boss.unit)")
                    Spacer()
                    Text("\(Int(boss.progress * 100))% defeated")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func deadlineText(_ d: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: d)).day ?? 0
        if days < 0 { return "Overdue by \(-days) days" }
        if days == 0 { return "Deadline: today!" }
        return "\(days) days left"
    }
}

struct AddHabitSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "✅"
    @State private var attribute = Attribute.discipline

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("e.g. Journal, Cold shower, Practice guitar", text: $name)
                    EmojiPicker(selection: $emoji, options: Emojis.habits)
                }
                Section {
                    Picker("Stat", selection: $attribute) {
                        ForEach(Attribute.allCases) { a in
                            Text("\(a.emoji) \(a.title)").tag(a)
                        }
                    }
                } footer: {
                    Text("Completing this habit levels up the stat you choose.")
                }
                Section("Ideas") {
                    ForEach(StarterHabit.suggestions) { s in
                        Button {
                            name = s.name
                            emoji = s.emoji
                            attribute = s.attribute
                        } label: {
                            Text("\(s.emoji) \(s.name)").foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addHabit(Habit(name: name.trimmingCharacters(in: .whitespaces), emoji: emoji, attribute: attribute))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct BossTemplate: Identifiable {
    let name: String
    let emoji: String
    let target: Double
    let unit: String
    let attribute: Attribute
    var id: String { name }

    static let all: [BossTemplate] = [
        BossTemplate(name: "Read 12 books", emoji: "🐉", target: 12, unit: "books", attribute: .intellect),
        BossTemplate(name: "Lose 5 kg", emoji: "👹", target: 5, unit: "kg", attribute: .vitality),
        BossTemplate(name: "Run 100 km", emoji: "🦖", target: 100, unit: "km", attribute: .strength),
        BossTemplate(name: "Study 50 hours for finals", emoji: "🧟", target: 50, unit: "hours", attribute: .intellect),
        BossTemplate(name: "Save €1000", emoji: "💀", target: 1000, unit: "€", attribute: .discipline),
        BossTemplate(name: "30 gym sessions", emoji: "🧌", target: 30, unit: "sessions", attribute: .strength),
    ]
}

struct AddBossSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🐉"
    @State private var target = ""
    @State private var unit = ""
    @State private var attribute = Attribute.discipline
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Num.parse(target) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("The boss") {
                    TextField("Goal (e.g. Read 12 books)", text: $name)
                    EmojiPicker(selection: $emoji, options: Emojis.bosses)
                }
                Section {
                    HStack {
                        TextField("Target HP", text: $target).keyboardType(.decimalPad)
                        TextField("unit (books, kg, km…)", text: $unit)
                    }
                    Picker("Stat", selection: $attribute) {
                        ForEach(Attribute.allCases) { a in
                            Text("\(a.emoji) \(a.title)").tag(a)
                        }
                    }
                    Toggle("Deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Defeat by", selection: $deadline, displayedComponents: .date)
                    }
                } header: {
                    Text("Health points")
                } footer: {
                    Text("The boss's HP is your target. Each hit gives +10 XP, and defeating it gives +150 XP.")
                }
                Section("Templates") {
                    ForEach(BossTemplate.all) { t in
                        Button {
                            name = t.name
                            emoji = t.emoji
                            target = Num.text(t.target)
                            unit = t.unit
                            attribute = t.attribute
                        } label: {
                            Text("\(t.emoji) \(t.name)").foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Summon a boss")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Summon") {
                        store.addBoss(Boss(
                            name: name.trimmingCharacters(in: .whitespaces),
                            emoji: emoji,
                            attribute: attribute,
                            target: Num.parse(target) ?? 1,
                            unit: unit.trimmingCharacters(in: .whitespaces),
                            deadline: hasDeadline ? deadline : nil
                        ))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
        }
    }
}
