import Foundation
import SwiftUI

final class Store: ObservableObject {
    @Published var data: AppData {
        didSet { save() }
    }
    @Published var levelUpTo: Int? = nil
    @Published var toast: String? = nil

    private let fileURL: URL
    private var toastQueue: [String] = []

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("maxgeneration-data.json")
        self.fileURL = url
        if let raw = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            self.data = decoded
        } else {
            self.data = AppData()
        }
    }

    // MARK: Persistence

    func save() {
        do {
            let raw = try JSONEncoder().encode(data)
            try raw.write(to: fileURL, options: [.atomic])
        } catch {
            print("Save failed: \(error)")
        }
    }

    func exportFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MaxGeneration-backup-\(Day.key()).json")
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: url, options: [.atomic])
        }
        return url
    }

    func importData(from url: URL) -> Bool {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppData.self, from: raw) else { return false }
        data = decoded
        return true
    }

    func resetAll() {
        data = AppData()
    }

    // MARK: Profile

    var profile: Profile { data.profile ?? Profile.default }

    func has(_ area: Area) -> Bool { profile.areas.contains(area) }

    // MARK: XP & levels

    var totalXP: Int { data.xpEvents.reduce(0) { $0 + $1.amount } }

    var level: Int { Leveling.info(totalXP).level }

    func xp(_ attribute: Attribute) -> Int {
        data.xpEvents.filter { $0.attribute == attribute }.reduce(0) { $0 + $1.amount }
    }

    func xpToday() -> Int {
        data.xpEvents.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }

    var activeDays: Set<String> { Set(data.xpEvents.map { Day.key($0.date) }) }
    var streak: Int { Streaks.current(activeDays) }
    var bestStreak: Int { Streaks.best(activeDays) }

    func award(_ amount: Int, _ attribute: Attribute, _ reason: String, key: String? = nil) {
        guard amount > 0 else { return }
        if let key = key, data.xpEvents.contains(where: { $0.sourceKey == key }) { return }
        let before = level
        data.xpEvents.append(XPEvent(date: Date(), amount: amount, attribute: attribute, reason: reason, sourceKey: key))
        let after = level
        if after > before {
            levelUpTo = after
            Haptics.success()
        }
        checkAchievements()
    }

    func revoke(key: String) {
        data.xpEvents.removeAll { $0.sourceKey == key }
    }

    func revoke(prefix: String) {
        data.xpEvents.removeAll { ($0.sourceKey ?? "").hasPrefix(prefix) }
    }

    // MARK: Toasts

    func showToast(_ text: String) {
        toastQueue.append(text)
        if toast == nil { advanceToast() }
    }

    private func advanceToast() {
        guard !toastQueue.isEmpty else {
            toast = nil
            return
        }
        toast = toastQueue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            self?.advanceToast()
        }
    }

    // MARK: Achievements

    func isUnlocked(_ a: Achievement) -> Bool { a.check(self) }

    func checkAchievements(silent: Bool = false) {
        let unlocked = Achievement.all.filter { $0.check(self) }
        let fresh = unlocked.filter { !data.seenAchievements.contains($0.id) }
        guard !fresh.isEmpty else { return }
        data.seenAchievements.append(contentsOf: fresh.map { $0.id })
        if !silent {
            for a in fresh { showToast("\(a.emoji) Achievement unlocked: \(a.title)") }
        }
    }

    // MARK: Gym

    static func e1rm(_ s: SetEntry) -> Double {
        guard s.reps > 0, s.weight > 0 else { return 0 }
        return s.weight * (1 + Double(s.reps) / 30.0)
    }

    func bestE1RM(_ exercise: String, excluding id: UUID? = nil) -> Double {
        let target = exercise.lowercased()
        var best = 0.0
        for w in data.workouts where w.id != id {
            for ex in w.exercises where ex.name.lowercased() == target {
                for s in ex.sets { best = max(best, Store.e1rm(s)) }
            }
        }
        return best
    }

    func saveWorkout(_ workout: Workout) {
        let key = "w:\(workout.id.uuidString)"
        revoke(prefix: key)
        data.workouts.removeAll { $0.id == workout.id }

        var prs: [String] = []
        for ex in workout.exercises {
            let previous = bestE1RM(ex.name, excluding: workout.id)
            let current = ex.sets.map { Store.e1rm($0) }.max() ?? 0
            if previous > 0 && current > previous + 0.01 { prs.append(ex.name) }
        }

        var list = data.workouts
        list.append(workout)
        list.sort { $0.date > $1.date }
        data.workouts = list

        award(min(80, 20 + workout.setCount * 2), .strength, "Workout: \(workout.title)", key: key)
        for name in prs {
            award(25, .strength, "New PR: \(name)", key: "\(key):pr:\(name)")
        }
        if !prs.isEmpty {
            showToast("🏆 New PR: " + prs.joined(separator: ", "))
            Haptics.success()
        }
    }

    func deleteWorkout(_ id: UUID) {
        data.workouts.removeAll { $0.id == id }
        revoke(prefix: "w:\(id.uuidString)")
    }

    var exerciseNames: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for w in data.workouts {
            for ex in w.exercises {
                let k = ex.name.lowercased()
                if !seen.contains(k) {
                    seen.insert(k)
                    out.append(ex.name)
                }
            }
        }
        return out
    }

    /// Latest workout for each distinct name, for one-tap "repeat".
    func workoutTemplates(limit: Int = 4) -> [Workout] {
        var seen = Set<String>()
        var out: [Workout] = []
        for w in data.workouts {
            let k = w.title.lowercased()
            if !seen.contains(k) && !w.exercises.isEmpty {
                seen.insert(k)
                out.append(w)
            }
            if out.count >= limit { break }
        }
        return out
    }

    func progress(for exercise: String) -> [ChartPoint] {
        let target = exercise.lowercased()
        var points: [ChartPoint] = []
        for w in data.workouts {
            var best = 0.0
            for ex in w.exercises where ex.name.lowercased() == target {
                for s in ex.sets { best = max(best, Store.e1rm(s)) }
            }
            if best > 0 { points.append(ChartPoint(date: w.date, value: best)) }
        }
        return points.sorted { $0.date < $1.date }
    }

    func history(for exercise: String) -> [ExerciseLog] {
        let target = exercise.lowercased()
        var logs: [ExerciseLog] = []
        for w in data.workouts {
            let sets = w.exercises.filter { $0.name.lowercased() == target }.flatMap { $0.sets }
            if !sets.isEmpty { logs.append(ExerciseLog(id: w.id, date: w.date, sets: sets)) }
        }
        return logs
    }

    func workoutsThisWeek() -> Int {
        guard let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return data.workouts.filter { $0.date >= start }.count + data.boxing.filter { $0.date >= start }.count
    }

    func addBodyweight(_ kg: Double, date: Date = Date()) {
        let entry = BodyweightEntry(date: date, kg: kg)
        var list = data.bodyweight
        list.append(entry)
        list.sort { $0.date > $1.date }
        data.bodyweight = list
        award(5, .vitality, "Weigh-in", key: "bw:\(entry.id.uuidString)")
    }

    func deleteBodyweight(_ id: UUID) {
        data.bodyweight.removeAll { $0.id == id }
        revoke(key: "bw:\(id.uuidString)")
    }

    // MARK: Study

    func studyMinutes(on day: Date) -> Int {
        data.studySessions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.minutes }
    }

    var totalStudyMinutes: Int { data.studySessions.reduce(0) { $0 + $1.minutes } }

    func addStudy(_ session: StudySession) {
        let before = studyMinutes(on: session.date)
        var list = data.studySessions
        list.append(session)
        list.sort { $0.date > $1.date }
        data.studySessions = list

        let subject = session.subject.trimmingCharacters(in: .whitespaces)
        if !subject.isEmpty && !data.subjects.contains(subject) {
            data.subjects.append(subject)
        }

        let key = "s:\(session.id.uuidString)"
        award(max(5, session.minutes / 2), .intellect, "Studied \(subject) (\(session.minutes)m)", key: key)

        let target = profile.studyMinutesTarget
        let after = before + session.minutes
        if target > 0 && before < target && after >= target {
            award(20, .intellect, "Daily study target hit", key: "\(key):target")
            showToast("🧠 Study target complete!")
        }
    }

    func deleteStudy(_ id: UUID) {
        data.studySessions.removeAll { $0.id == id }
        revoke(prefix: "s:\(id.uuidString)")
    }

    func minutesBySubject() -> [SubjectTotal] {
        var totals: [String: Int] = [:]
        for s in data.studySessions { totals[s.subject, default: 0] += s.minutes }
        return totals.map { SubjectTotal(subject: $0.key, minutes: $0.value) }.sorted { $0.minutes > $1.minutes }
    }

    func studyLastDays(_ count: Int) -> [ChartPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [ChartPoint] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            if let day = cal.date(byAdding: .day, value: -offset, to: today) {
                out.append(ChartPoint(date: day, value: Double(studyMinutes(on: day))))
            }
        }
        return out
    }

    // MARK: Food

    func foods(on day: Date) -> [FoodEntry] {
        data.foods.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func calories(on day: Date) -> Int { foods(on: day).reduce(0) { $0 + $1.calories } }
    func protein(on day: Date) -> Int { foods(on: day).reduce(0) { $0 + $1.protein } }

    func addFood(_ food: FoodEntry) {
        let before = protein(on: food.date)
        data.foods.append(food)
        let key = "f:\(food.id.uuidString)"
        award(5, .vitality, "Logged \(food.name)", key: key)
        let target = profile.proteinTarget
        let after = before + food.protein
        if target > 0 && before < target && after >= target {
            award(20, .vitality, "Protein target hit", key: "\(key):protein")
            showToast("🥩 Protein target smashed!")
        }
    }

    func deleteFood(_ id: UUID) {
        data.foods.removeAll { $0.id == id }
        revoke(prefix: "f:\(id.uuidString)")
    }

    var recentFoods: [FoodEntry] {
        var seen = Set<String>()
        var out: [FoodEntry] = []
        for f in data.foods.sorted(by: { $0.date > $1.date }) {
            let k = f.name.lowercased()
            if !seen.contains(k) {
                seen.insert(k)
                out.append(f)
            }
            if out.count >= 12 { break }
        }
        return out
    }

    func water(on day: Date) -> Int { data.water[Day.key(day)] ?? 0 }

    func changeWater(on day: Date, by delta: Int) {
        let k = Day.key(day)
        let current = data.water[k] ?? 0
        let updated = max(0, current + delta)
        guard updated != current else { return }
        data.water[k] = updated
        let target = profile.waterTarget
        if delta > 0 {
            if updated <= target {
                award(2, .vitality, "Glass of water", key: "water:\(k):\(updated)")
            }
            if updated == target {
                award(10, .vitality, "Hydration goal hit", key: "water:\(k):goal")
                showToast("💧 Hydration goal hit!")
            }
            Haptics.tap()
        } else {
            revoke(key: "water:\(k):\(current)")
            if current == target { revoke(key: "water:\(k):goal") }
        }
    }

    // MARK: Habits

    func isDone(_ habit: Habit, on day: Date = Date()) -> Bool {
        habit.completions.contains(Day.key(day))
    }

    func toggle(_ habit: Habit, on day: Date = Date()) {
        guard let i = data.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let k = Day.key(day)
        let key = "h:\(habit.id.uuidString):\(k)"
        if data.habits[i].completions.contains(k) {
            data.habits[i].completions.remove(k)
            revoke(key: key)
        } else {
            data.habits[i].completions.insert(k)
            award(10, habit.attribute, "\(habit.emoji) \(habit.name)", key: key)
            Haptics.tap()
        }
    }

    func addHabit(_ habit: Habit) { data.habits.append(habit) }

    func deleteHabit(_ id: UUID) {
        data.habits.removeAll { $0.id == id }
        revoke(prefix: "h:\(id.uuidString)")
    }

    // MARK: Bosses

    var activeBosses: [Boss] { data.bosses.filter { $0.defeatedAt == nil } }
    var defeatedBosses: [Boss] { data.bosses.filter { $0.defeatedAt != nil } }

    func addBoss(_ boss: Boss) { data.bosses.append(boss) }

    func hit(_ boss: Boss, amount: Double) {
        guard amount > 0,
              let i = data.bosses.firstIndex(where: { $0.id == boss.id }),
              data.bosses[i].defeatedAt == nil else { return }
        let hit = BossHit(date: Date(), amount: amount)
        data.bosses[i].hits.append(hit)
        let base = "b:\(boss.id.uuidString)"
        award(10, boss.attribute, "Hit \(boss.name)", key: "\(base):\(hit.id.uuidString)")
        if data.bosses[i].hpLeft <= 0 {
            data.bosses[i].defeatedAt = Date()
            award(150, boss.attribute, "Defeated \(boss.name)!", key: "\(base):defeat")
            showToast("⚔️ \(boss.name) defeated! +150 XP")
            Haptics.success()
        } else {
            Haptics.tap()
        }
    }

    func deleteBoss(_ id: UUID) {
        data.bosses.removeAll { $0.id == id }
        revoke(prefix: "b:\(id.uuidString)")
        checkAchievements(silent: true)
    }

    // MARK: Daily quests

    func todaysQuests() -> [Quest] {
        let today = Date()
        let p = profile
        var list: [Quest] = []

        // Body quests (always on)
        let sleepMins = dayLog(today).sleepMinutes ?? 0
        let sleepQuest = (Quest(kind: .sleep, title: "Sleep \(Num.text(p.sleepTargetHours)) hours", emoji: "😴", xp: 30,
                          attribute: .vitality, current: Double(sleepMins) / 60.0, target: p.sleepTargetHours, unit: "h"))
        if !p.supplements.isEmpty {
            list.append(Quest(kind: .supplements, title: "Take all your supplements", emoji: "💊", xp: 20,
                              attribute: .vitality, current: Double(supplementsTakenCount(on: today)),
                              target: Double(p.supplements.count), unit: ""))
        }

        if has(.gym) {
            let todays = data.workouts.filter { Calendar.current.isDateInToday($0.date) }
            let sets = todays.reduce(0) { $0 + $1.setCount }
            list.append(Quest(kind: .workout, title: "Train today (gym or boxing)", emoji: "🥊", xp: 30,
                              attribute: .strength, current: trained(on: today) ? 1 : 0, target: 1, unit: ""))
            list.append(Quest(kind: .sets, title: "Crush 15 working sets", emoji: "🔩", xp: 35,
                              attribute: .strength, current: Double(sets), target: 15, unit: "sets"))
            list.append(Quest(kind: .boxing, title: "Box for 45 minutes", emoji: "🥊", xp: 35,
                              attribute: .strength, current: Double(boxingMinutes(on: today)), target: 45, unit: "min"))
        }
        if has(.study) {
            let mins = Double(studyMinutes(on: today))
            let half = max(15, p.studyMinutesTarget / 2)
            list.append(Quest(kind: .study, title: "Study \(half) minutes", emoji: "📚", xp: 25,
                              attribute: .intellect, current: mins, target: Double(half), unit: "min"))
            list.append(Quest(kind: .studyLong, title: "Hit your \(p.studyMinutesTarget)-min study goal", emoji: "🧠", xp: 40,
                              attribute: .intellect, current: mins, target: Double(max(1, p.studyMinutesTarget)), unit: "min"))
        }
        if has(.food) {
            list.append(Quest(kind: .protein, title: "Eat \(p.proteinTarget)g protein", emoji: "🥩", xp: 30,
                              attribute: .vitality, current: Double(protein(on: today)), target: Double(max(1, p.proteinTarget)), unit: "g"))
            list.append(Quest(kind: .water, title: "Drink \(p.waterTarget) cups of water", emoji: "💧", xp: 20,
                              attribute: .vitality, current: Double(water(on: today)), target: Double(max(1, p.waterTarget)), unit: ""))
            let meals = Set(foods(on: today).map { $0.meal }).count
            list.append(Quest(kind: .meals, title: "Log 3 different meals", emoji: "🍽️", xp: 20,
                              attribute: .vitality, current: Double(meals), target: 3, unit: ""))
        }
        if has(.life) {
            if !data.habits.isEmpty {
                let done = data.habits.filter { isDone($0, on: today) }.count
                list.append(Quest(kind: .habits, title: "Complete all your habits", emoji: "✅", xp: 40,
                                  attribute: .discipline, current: Double(done), target: Double(data.habits.count), unit: ""))
            }
            if !activeBosses.isEmpty {
                let hitToday = activeBosses.contains { b in b.hits.contains { Calendar.current.isDateInToday($0.date) } }
                list.append(Quest(kind: .boss, title: "Deal damage to a boss", emoji: "⚔️", xp: 25,
                                  attribute: .discipline, current: hitToday ? 1 : 0, target: 1, unit: ""))
            }
        }

        // Sleep is always quest #1, plus 3 random ones that change every day.
        var generator = SeededGenerator(seed: Day.seed(today))
        let shuffled = list.shuffled(using: &generator)
        return [sleepQuest] + Array(shuffled.prefix(3))
    }

    func isClaimed(_ quest: Quest) -> Bool {
        data.claimedQuests[Day.key()]?.contains(quest.id) ?? false
    }

    func claim(_ quest: Quest) {
        guard quest.isDone, !isClaimed(quest) else { return }
        let k = Day.key()
        var claimed = data.claimedQuests[k] ?? []
        claimed.append(quest.id)
        data.claimedQuests[k] = claimed
        award(quest.xp, quest.attribute, "Quest: \(quest.title)", key: "q:\(k):\(quest.id)")
        let quests = todaysQuests()
        if !quests.isEmpty && quests.allSatisfy({ isClaimed($0) }) {
            award(50, .discipline, "Perfect Day bonus", key: "perfect:\(k)")
            showToast("✨ Perfect Day! +50 XP")
        }
        Haptics.success()
    }

    // MARK: Onboarding

    func finishOnboarding(profile: Profile, habits: [Habit]) {
        data.habits.append(contentsOf: habits)
        data.profile = profile
        award(10, .discipline, "Began the adventure", key: "start")
    }
}
