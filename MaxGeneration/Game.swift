import Foundation
import UIKit
import UserNotifications

// MARK: - Days

enum Day {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date = Date()) -> String { formatter.string(from: date) }
    static func date(from key: String) -> Date? { formatter.date(from: key) }

    /// Stable seed for a day (String.hashValue changes every launch, so we roll our own).
    static func seed(_ date: Date = Date()) -> UInt64 {
        var h: UInt64 = 5381
        for b in key(date).utf8 { h = (h &* 33) &+ UInt64(b) }
        return h
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Levels

struct LevelInfo {
    let level: Int
    let into: Int
    let needed: Int
    var fraction: Double { needed > 0 ? Double(into) / Double(needed) : 0 }
}

enum Leveling {
    static func xpToNext(_ level: Int) -> Int { 100 + (level - 1) * 50 }

    static func info(_ totalXP: Int) -> LevelInfo {
        var level = 1
        var remaining = max(0, totalXP)
        while remaining >= xpToNext(level) {
            remaining -= xpToNext(level)
            level += 1
        }
        return LevelInfo(level: level, into: remaining, needed: xpToNext(level))
    }

    /// Attribute levels grow a bit faster so they feel responsive.
    static func attributeInfo(_ xp: Int) -> LevelInfo {
        var level = 1
        var remaining = max(0, xp)
        while remaining >= 60 + (level - 1) * 30 {
            remaining -= 60 + (level - 1) * 30
            level += 1
        }
        return LevelInfo(level: level, into: remaining, needed: 60 + (level - 1) * 30)
    }

    static func title(for level: Int) -> String {
        switch level {
        case ..<3: return "Novice"
        case 3..<6: return "Apprentice"
        case 6..<10: return "Adventurer"
        case 10..<15: return "Warrior"
        case 15..<20: return "Champion"
        case 20..<30: return "Hero"
        case 30..<40: return "Legend"
        default: return "Mythic"
        }
    }
}

// MARK: - Streaks

enum Streaks {
    static func current(_ days: Set<String>) -> Int {
        let cal = Calendar.current
        var date = Date()
        if !days.contains(Day.key(date)) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }
        var count = 0
        while days.contains(Day.key(date)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return count
    }

    static func best(_ days: Set<String>) -> Int {
        let cal = Calendar.current
        let dates = days.compactMap { Day.date(from: $0) }.sorted()
        var best = 0
        var run = 0
        var last: Date? = nil
        for d in dates {
            if let l = last, let next = cal.date(byAdding: .day, value: 1, to: l), cal.isDate(next, inSameDayAs: d) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            last = d
        }
        return best
    }
}

// MARK: - Quests

enum QuestKind: String, CaseIterable {
    case workout, sets, boxing, sleep, supplements, study, studyLong, protein, water, meals, habits, boss
}

struct Quest: Identifiable {
    let kind: QuestKind
    let title: String
    let emoji: String
    let xp: Int
    let attribute: Attribute
    let current: Double
    let target: Double
    let unit: String

    var id: String { kind.rawValue }
    var isDone: Bool { current >= target }
    var fraction: Double { target > 0 ? min(1, current / target) : 0 }
    var progressText: String {
        let c = Num.text((min(current, target) * 10).rounded() / 10)
        let t = Num.text(target)
        return unit.isEmpty ? "\(c) / \(t)" : "\(c) / \(t) \(unit)"
    }
}

// MARK: - Achievements

struct Achievement: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let detail: String
    let check: (Store) -> Bool

    static let all: [Achievement] = [
        Achievement(id: "first_workout", emoji: "🏋️", title: "First Rep", detail: "Log your first workout") { $0.data.workouts.count >= 1 },
        Achievement(id: "workouts_10", emoji: "💪", title: "Gym Regular", detail: "Log 10 workouts") { $0.data.workouts.count >= 10 },
        Achievement(id: "workouts_50", emoji: "🦍", title: "Iron Addict", detail: "Log 50 workouts") { $0.data.workouts.count >= 50 },
        Achievement(id: "workouts_100", emoji: "🗿", title: "Unbreakable", detail: "Log 100 workouts") { $0.data.workouts.count >= 100 },
        Achievement(id: "first_pr", emoji: "🏆", title: "Personal Best", detail: "Set your first PR") { s in
            s.data.xpEvents.contains { ($0.sourceKey ?? "").contains(":pr:") }
        },
        Achievement(id: "study_1h", emoji: "📖", title: "Bookworm", detail: "Study for 1 hour total") { $0.totalStudyMinutes >= 60 },
        Achievement(id: "study_10h", emoji: "🎓", title: "Scholar", detail: "Study for 10 hours total") { $0.totalStudyMinutes >= 600 },
        Achievement(id: "study_100h", emoji: "🧙", title: "Archmage", detail: "Study for 100 hours total") { $0.totalStudyMinutes >= 6000 },
        Achievement(id: "meals_10", emoji: "🍽️", title: "Food Logger", detail: "Log 10 meals") { $0.data.foods.count >= 10 },
        Achievement(id: "meals_100", emoji: "👨‍🍳", title: "Nutrition Nerd", detail: "Log 100 meals") { $0.data.foods.count >= 100 },
        Achievement(id: "hydrated", emoji: "💧", title: "Hydrated", detail: "Hit your water goal") { s in
            s.data.water.values.contains { $0 >= s.profile.waterTarget }
        },
        Achievement(id: "streak_3", emoji: "🔥", title: "On Fire", detail: "3-day activity streak") { $0.bestStreak >= 3 },
        Achievement(id: "streak_7", emoji: "☄️", title: "Week Warrior", detail: "7-day activity streak") { $0.bestStreak >= 7 },
        Achievement(id: "streak_30", emoji: "🌋", title: "Unstoppable", detail: "30-day activity streak") { $0.bestStreak >= 30 },
        Achievement(id: "level_5", emoji: "⭐", title: "Rising Star", detail: "Reach level 5") { $0.level >= 5 },
        Achievement(id: "level_10", emoji: "🌟", title: "Warrior", detail: "Reach level 10") { $0.level >= 10 },
        Achievement(id: "level_25", emoji: "👑", title: "Hero of Legend", detail: "Reach level 25") { $0.level >= 25 },
        Achievement(id: "boss_1", emoji: "⚔️", title: "Boss Slayer", detail: "Defeat your first boss") { s in
            s.data.bosses.contains { $0.defeatedAt != nil }
        },
        Achievement(id: "boss_5", emoji: "🐉", title: "Dragon Hunter", detail: "Defeat 5 bosses") { s in
            s.data.bosses.filter { $0.defeatedAt != nil }.count >= 5
        },
        Achievement(id: "habits_50", emoji: "✅", title: "Creature of Habit", detail: "Complete 50 habits") { s in
            s.data.habits.reduce(0) { $0 + $1.completions.count } >= 50
        },
        Achievement(id: "well_rested", emoji: "😴", title: "Well Rested", detail: "Hit your sleep goal") { s in
            s.data.dayLogs.values.contains { ($0.sleepMinutes ?? 0) >= s.sleepTargetMinutes }
        },
        Achievement(id: "first_box", emoji: "🥊", title: "Gloves On", detail: "Log your first boxing session") { $0.data.boxing.count >= 1 },
        Achievement(id: "box_20", emoji: "🥋", title: "Ring Veteran", detail: "Log 20 boxing sessions") { $0.data.boxing.count >= 20 },
        Achievement(id: "rank_a", emoji: "🅰️", title: "A-Game", detail: "Finish a day with rank A or better") { $0.countRanks(["A", "S", "S+"]) >= 1 },
        Achievement(id: "rank_s", emoji: "🌠", title: "S-Rank", detail: "Finish a day with rank S or better") { $0.countRanks(["S", "S+"]) >= 1 },
        Achievement(id: "rank_splus", emoji: "💎", title: "Flawless", detail: "Finish a day with rank S+") { $0.countRanks(["S+"]) >= 1 },
        Achievement(id: "rank_s_10", emoji: "🌌", title: "Speed Demon", detail: "Get 10 S-rank days or better") { $0.countRanks(["S", "S+"]) >= 10 },
        Achievement(id: "perfect_day", emoji: "✨", title: "Perfect Day", detail: "Claim all daily quests in a day") { s in
            s.data.xpEvents.contains { ($0.sourceKey ?? "").hasPrefix("perfect:") }
        },
    ]
}

// MARK: - Haptics

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        SoundFX.play(.claim)
    }
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        SoundFX.play(.tap)
    }
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

// MARK: - Daily reminder

enum Reminders {
    static func schedule(hour: Int, minute: Int, name: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(withIdentifiers: ["daily-quests"])
            let content = UNMutableNotificationContent()
            content.title = "Your quests await, \(name) ⚔️"
            content.body = "Log today's progress and keep your streak alive."
            content.sound = .default
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "daily-quests", content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-quests"])
    }
}

// MARK: - Number helpers

enum Num {
    /// Parses "62.5" or "62,5" (Greek/European keyboards use a comma).
    static func parse(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    static func text(_ d: Double) -> String {
        if d == d.rounded() { return String(Int(d)) }
        return String(format: "%.1f", d)
    }
}
