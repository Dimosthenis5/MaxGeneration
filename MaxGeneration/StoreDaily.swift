import Foundation
import SwiftUI

// MARK: - Day score types

struct ScoreLine: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let detail: String
    let fraction: Double
    let weight: Double

    var points: Int { Int((min(max(fraction, 0), 1) * weight).rounded()) }
}

struct DayScore {
    let lines: [ScoreLine]
    let score: Int
    var rank: String { Rank.rank(for: score) }
}

struct RankDay: Identifiable {
    let id: String
    let date: Date
    let rank: String?
}

enum Rank {
    static func rank(for score: Int) -> String {
        switch score {
        case 95...: return "S+"
        case 85..<95: return "S"
        case 70..<85: return "A"
        case 50..<70: return "B"
        default: return "C"
        }
    }

    static func color(_ rank: String) -> Color {
        switch rank {
        case "S+": return Color(red: 1.0, green: 0.84, blue: 0.2)
        case "S": return Color(red: 1.0, green: 0.62, blue: 0.15)
        case "A": return Color(red: 0.35, green: 0.85, blue: 1.0)
        case "B": return Color(red: 0.4, green: 0.9, blue: 0.5)
        default: return Color(red: 0.75, green: 0.75, blue: 0.8)
        }
    }

    static func bonus(_ rank: String) -> Int {
        switch rank {
        case "S+": return 100
        case "S": return 75
        case "A": return 50
        case "B": return 30
        default: return 15
        }
    }

    static func message(_ rank: String) -> String {
        switch rank {
        case "S+": return "FLAWLESS. A legendary day."
        case "S": return "Outstanding run. Elite day."
        case "A": return "Great day. Almost perfect."
        case "B": return "Solid. You showed up."
        default: return "Day cleared. Tomorrow, go faster."
        }
    }
}

extension Store {

    // MARK: Day log

    func dayLog(_ day: Date = Date()) -> DayLog {
        data.dayLogs[Day.key(day)] ?? DayLog()
    }

    func updateDayLog(_ day: Date, _ change: (inout DayLog) -> Void) {
        let k = Day.key(day)
        var log = data.dayLogs[k] ?? DayLog()
        change(&log)
        data.dayLogs[k] = log
    }

    // MARK: Sleep

    static func sleepMinutes(bed: Date, wake: Date) -> Int {
        let cal = Calendar.current
        let b = cal.dateComponents([.hour, .minute], from: bed)
        let w = cal.dateComponents([.hour, .minute], from: wake)
        let bedMins = (b.hour ?? 0) * 60 + (b.minute ?? 0)
        let wakeMins = (w.hour ?? 0) * 60 + (w.minute ?? 0)
        var diff = wakeMins - bedMins
        if diff <= 0 { diff += 24 * 60 }
        return diff
    }

    static func hoursText(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var sleepTargetMinutes: Int { Int(profile.sleepTargetHours * 60) }

    func logSleep(day: Date, bed: Date, wake: Date) {
        let minutes = Store.sleepMinutes(bed: bed, wake: wake)
        let k = Day.key(day)
        updateDayLog(day) { log in
            log.sleepMinutes = minutes
            log.bedtime = bed
            log.wakeTime = wake
        }
        revoke(prefix: "sleep:\(k)")
        award(15, .vitality, "Logged sleep (\(Store.hoursText(minutes)))", key: "sleep:\(k)")
        if minutes >= sleepTargetMinutes {
            award(15, .vitality, "Sleep goal hit", key: "sleep:\(k):goal")
            showToast("😴 Fully recharged! Sleep goal hit")
        }
        Haptics.success()
    }

    func sleepLastDays(_ count: Int) -> [ChartPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [ChartPoint] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            if let day = cal.date(byAdding: .day, value: -offset, to: today) {
                let mins = dayLog(day).sleepMinutes ?? 0
                out.append(ChartPoint(date: day, value: Double(mins) / 60.0))
            }
        }
        return out
    }

    // MARK: Supplements

    func isTaken(_ s: Supplement, on day: Date = Date()) -> Bool {
        dayLog(day).supplementsTaken.contains(s.id.uuidString)
    }

    func toggleSupplement(_ s: Supplement, on day: Date = Date()) {
        let k = Day.key(day)
        let sid = s.id.uuidString
        let key = "sup:\(k):\(sid)"
        if isTaken(s, on: day) {
            updateDayLog(day) { log in log.supplementsTaken.removeAll { $0 == sid } }
            revoke(key: key)
            revoke(key: "sup:\(k):all")
        } else {
            updateDayLog(day) { log in log.supplementsTaken.append(sid) }
            award(5, .vitality, "\(s.emoji) \(s.name)", key: key)
            let all = profile.supplements
            if !all.isEmpty && all.allSatisfy({ isTaken($0, on: day) }) {
                award(10, .vitality, "All supplements taken", key: "sup:\(k):all")
                showToast("💊 Stack complete!")
            }
            Haptics.tap()
        }
    }

    func supplementsTakenCount(on day: Date = Date()) -> Int {
        profile.supplements.filter { isTaken($0, on: day) }.count
    }

    // MARK: Boxing

    func addBoxing(_ session: BoxingSession) {
        var list = data.boxing
        list.append(session)
        list.sort { $0.date > $1.date }
        data.boxing = list
        award(min(80, 15 + session.minutes / 2), .strength, "Boxing \(session.minutes) min 🥊", key: "box:\(session.id.uuidString)")
        Haptics.success()
    }

    func deleteBoxing(_ id: UUID) {
        data.boxing.removeAll { $0.id == id }
        revoke(key: "box:\(id.uuidString)")
    }

    func boxingMinutes(on day: Date) -> Int {
        data.boxing.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
    }

    func trained(on day: Date) -> Bool {
        data.workouts.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
            || data.boxing.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: Day score & rank

    func dayScore(_ day: Date = Date()) -> DayScore {
        let p = profile
        var lines: [ScoreLine] = []

        let sleep = dayLog(day).sleepMinutes
        lines.append(ScoreLine(
            id: "sleep", emoji: "😴", title: "Sleep",
            detail: sleep.map { "\(Store.hoursText($0)) / \(Num.text(p.sleepTargetHours))h" } ?? "Not logged",
            fraction: Double(sleep ?? 0) / Double(max(1, sleepTargetMinutes)), weight: 20))

        if has(.gym) {
            let gym = data.workouts.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
            let box = boxingMinutes(on: day)
            var parts: [String] = []
            if gym { parts.append("Gym") }
            if box > 0 { parts.append("Boxing \(box)m") }
            lines.append(ScoreLine(
                id: "train", emoji: "🥊", title: "Training",
                detail: parts.isEmpty ? "Rest day" : parts.joined(separator: " + "),
                fraction: parts.isEmpty ? 0.3 : 1, weight: 20))
        }

        if has(.food) {
            let prot = protein(on: day)
            lines.append(ScoreLine(
                id: "protein", emoji: "🥩", title: "Protein",
                detail: "\(prot) / \(p.proteinTarget) g",
                fraction: Double(prot) / Double(max(1, p.proteinTarget)), weight: 15))

            let kcal = calories(on: day)
            let target = Double(max(1, p.calorieTarget))
            let off = abs(Double(kcal) - target) / (target * 0.5)
            lines.append(ScoreLine(
                id: "kcal", emoji: "🔥", title: "Calories",
                detail: "\(kcal) / \(p.calorieTarget) kcal",
                fraction: kcal == 0 ? 0 : max(0, 1 - off), weight: 10))

            let cups = water(on: day)
            lines.append(ScoreLine(
                id: "water", emoji: "💧", title: "Water",
                detail: "\(cups) / \(p.waterTarget) cups",
                fraction: Double(cups) / Double(max(1, p.waterTarget)), weight: 10))
        }

        if !p.supplements.isEmpty {
            let taken = supplementsTakenCount(on: day)
            lines.append(ScoreLine(
                id: "supps", emoji: "💊", title: "Supplements",
                detail: "\(taken) / \(p.supplements.count)",
                fraction: Double(taken) / Double(p.supplements.count), weight: 10))
        }

        if has(.study) {
            let mins = studyMinutes(on: day)
            lines.append(ScoreLine(
                id: "study", emoji: "📚", title: "Study",
                detail: "\(mins) / \(p.studyMinutesTarget) min",
                fraction: Double(mins) / Double(max(1, p.studyMinutesTarget)), weight: 10))
        }

        if has(.life) && !data.habits.isEmpty {
            let done = data.habits.filter { isDone($0, on: day) }.count
            lines.append(ScoreLine(
                id: "habits", emoji: "✅", title: "Habits",
                detail: "\(done) / \(data.habits.count)",
                fraction: Double(done) / Double(data.habits.count), weight: 5))
        }

        let totalWeight = lines.reduce(0.0) { $0 + $1.weight }
        let earned = lines.reduce(0.0) { $0 + min(max($1.fraction, 0), 1) * $1.weight }
        let score = totalWeight > 0 ? Int((earned / totalWeight * 100).rounded()) : 0
        return DayScore(lines: lines, score: score)
    }

    /// Locks in today's rank and gives the rank bonus. Finishing again later updates it.
    func finishDay() -> DayScore {
        let result = dayScore()
        let k = Day.key()
        updateDayLog(Date()) { log in
            log.finalScore = result.score
            log.finalRank = result.rank
        }
        revoke(key: "rank:\(k)")
        award(Rank.bonus(result.rank), .discipline, "Day rank \(result.rank)", key: "rank:\(k)")
        return result
    }

    func rankHistory(_ count: Int) -> [RankDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [RankDay] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            if let day = cal.date(byAdding: .day, value: -offset, to: today) {
                out.append(RankDay(id: Day.key(day), date: day, rank: dayLog(day).finalRank))
            }
        }
        return out
    }

    func countRanks(_ ranks: [String]) -> Int {
        data.dayLogs.values.filter { log in
            guard let r = log.finalRank else { return false }
            return ranks.contains(r)
        }.count
    }
}

// MARK: - Weekly goals & check-in

struct WeekSummary: Identifiable {
    let id: String
    let start: Date
    let log: WeekLog
}

extension Store {
    static var weekCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Monday
        c.timeZone = TimeZone.current
        return c
    }

    func weekStart(_ date: Date = Date()) -> Date {
        Store.weekCalendar.dateInterval(of: .weekOfYear, for: date)?.start ?? Calendar.current.startOfDay(for: date)
    }

    func weekKey(_ date: Date = Date()) -> String { Day.key(weekStart(date)) }

    var lastWeekDate: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    func weekLog(_ date: Date = Date()) -> WeekLog {
        data.weekLogs[weekKey(date)] ?? WeekLog()
    }

    func updateWeekLog(_ date: Date, _ change: (inout WeekLog) -> Void) {
        let k = weekKey(date)
        var log = data.weekLogs[k] ?? WeekLog()
        change(&log)
        data.weekLogs[k] = log
    }

    func addWeekGoal(_ text: String, week: Date = Date()) {
        let clean = text.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        updateWeekLog(week) { log in log.goals.append(WeekGoal(text: clean)) }
        Haptics.tap()
    }

    func toggleWeekGoal(_ goal: WeekGoal, week: Date = Date()) {
        let key = "wg:\(goal.id.uuidString)"
        updateWeekLog(week) { log in
            if let i = log.goals.firstIndex(where: { $0.id == goal.id }) { log.goals[i].done.toggle() }
        }
        if goal.done {
            revoke(key: key)
        } else {
            award(25, .discipline, "Week goal: \(goal.text)", key: key)
            Haptics.success()
        }
    }

    func deleteWeekGoal(_ id: UUID, week: Date = Date()) {
        updateWeekLog(week) { log in log.goals.removeAll { $0.id == id } }
        revoke(key: "wg:\(id.uuidString)")
    }

    /// Days of that week that have already happened (all 7 for past weeks).
    func elapsedDays(ofWeek date: Date) -> [Date] {
        let start = weekStart(date)
        let today = Calendar.current.startOfDay(for: Date())
        var out: [Date] = []
        for i in 0..<7 {
            if let d = Calendar.current.date(byAdding: .day, value: i, to: start), d <= today { out.append(d) }
        }
        return out
    }

    func sessions(inWeekOf date: Date) -> Int {
        let start = weekStart(date)
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return 0 }
        let gym = data.workouts.filter { $0.date >= start && $0.date < end }.count
        let box = data.boxing.filter { $0.date >= start && $0.date < end }.count
        return gym + box
    }

    func weekScore(_ date: Date = Date()) -> DayScore {
        let days = elapsedDays(ofWeek: date)
        let log = weekLog(date)
        var lines: [ScoreLine] = []

        let dailyScores = days.map { dayScore($0).score }
        let avg = dailyScores.isEmpty ? 0 : Double(dailyScores.reduce(0, +)) / Double(dailyScores.count)
        lines.append(ScoreLine(id: "daily", emoji: "📅", title: "Daily ranks",
                               detail: "Avg \(Int(avg.rounded())) (\(Rank.rank(for: Int(avg.rounded())))) over \(days.count) days",
                               fraction: avg / 100, weight: 50))

        let done = log.goals.filter { $0.done }.count
        lines.append(ScoreLine(id: "goals", emoji: "🎯", title: "Week goals",
                               detail: log.goals.isEmpty ? "No goals set" : "\(done) / \(log.goals.count) done",
                               fraction: log.goals.isEmpty ? 0 : Double(done) / Double(log.goals.count), weight: 25))

        if has(.gym) {
            let s = sessions(inWeekOf: date)
            lines.append(ScoreLine(id: "train", emoji: "🏋️", title: "Training sessions",
                                   detail: "\(s) / \(profile.workoutsPerWeek)",
                                   fraction: Double(s) / Double(max(1, profile.workoutsPerWeek)), weight: 15))
        }

        let checked = log.weightKg != nil || log.bodyFat != nil
        lines.append(ScoreLine(id: "body", emoji: "📏", title: "Body check-in",
                               detail: checked ? "Logged" : "Not yet",
                               fraction: checked ? 1 : 0, weight: 10))

        let total = lines.reduce(0.0) { $0 + $1.weight }
        let earned = lines.reduce(0.0) { $0 + min(max($1.fraction, 0), 1) * $1.weight }
        return DayScore(lines: lines, score: Int((earned / total * 100).rounded()))
    }

    func finishWeek(_ date: Date, weight: Double?, bodyFat: Double?, feeling: Int, note: String) -> DayScore {
        updateWeekLog(date) { log in
            log.weightKg = weight
            log.bodyFat = bodyFat
            log.feeling = feeling
            log.note = note
        }
        if let w = weight {
            // Also add to the bodyweight chart, once per week.
            let k = weekKey(date)
            let alreadyLogged = data.bodyweight.contains { weekKey($0.date) == k && abs($0.kg - w) < 0.01 }
            if !alreadyLogged { addBodyweight(w) }
        }
        let result = weekScore(date)
        updateWeekLog(date) { log in
            log.finalScore = result.score
            log.finalRank = result.rank
        }
        let key = "week:\(weekKey(date))"
        revoke(key: key)
        award(Rank.bonus(result.rank) * 2, .discipline, "Week rank \(result.rank)", key: key)
        return result
    }

    var weekHistory: [WeekSummary] {
        data.weekLogs
            .filter { $0.value.finalRank != nil || $0.value.bodyFat != nil || $0.value.weightKg != nil }
            .compactMap { pair -> WeekSummary? in
                guard let d = Day.date(from: pair.key) else { return nil }
                return WeekSummary(id: pair.key, start: d, log: pair.value)
            }
            .sorted { $0.start > $1.start }
    }

    var lastWeekNeedsCheckIn: Bool {
        let log = weekLog(lastWeekDate)
        guard log.finalRank == nil else { return false }
        // Only nag if you actually used the app last week.
        let start = weekStart(lastWeekDate)
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return false }
        return data.xpEvents.contains { $0.date >= start && $0.date < end }
    }
}
