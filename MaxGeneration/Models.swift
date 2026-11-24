import Foundation

// MARK: - Core enums

enum Attribute: String, Codable, CaseIterable, Identifiable {
    case strength, intellect, vitality, discipline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: return "Strength"
        case .intellect: return "Intellect"
        case .vitality: return "Vitality"
        case .discipline: return "Discipline"
        }
    }

    var short: String {
        switch self {
        case .strength: return "STR"
        case .intellect: return "INT"
        case .vitality: return "VIT"
        case .discipline: return "DIS"
        }
    }

    var emoji: String {
        switch self {
        case .strength: return "💪"
        case .intellect: return "🧠"
        case .vitality: return "❤️"
        case .discipline: return "🔥"
        }
    }

    var blurb: String {
        switch self {
        case .strength: return "Gym & training"
        case .intellect: return "Studying & learning"
        case .vitality: return "Food, water & health"
        case .discipline: return "Habits & life goals"
        }
    }
}

enum Area: String, Codable, CaseIterable, Identifiable {
    case gym, study, food, life

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gym: return "Gym"
        case .study: return "Studies"
        case .food: return "Food"
        case .life: return "Life goals & habits"
        }
    }

    var emoji: String {
        switch self {
        case .gym: return "🏋️"
        case .study: return "📚"
        case .food: return "🍽️"
        case .life: return "🎯"
        }
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snacks"
        }
    }

    var emoji: String {
        switch self {
        case .breakfast: return "🍳"
        case .lunch: return "🥗"
        case .dinner: return "🍝"
        case .snack: return "🍎"
        }
    }

    static func guess(for date: Date = Date()) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<22: return .dinner
        default: return .snack
        }
    }
}

// MARK: - Profile

enum SupplementTime: String, Codable, CaseIterable, Identifiable {
    case morning, anytime, night
    var id: String { rawValue }
    var title: String {
        switch self {
        case .morning: return "Morning"
        case .anytime: return "Any time"
        case .night: return "Night"
        }
    }
    var emoji: String {
        switch self {
        case .morning: return "☀️"
        case .anytime: return "🕐"
        case .night: return "🌙"
        }
    }
}

struct Supplement: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String
    var time: SupplementTime

    static let defaults: [Supplement] = [
        Supplement(name: "Multivitamin", emoji: "💊", time: .morning),
        Supplement(name: "Omega-3", emoji: "🐟", time: .morning),
        Supplement(name: "Creatine", emoji: "⚡", time: .anytime),
        Supplement(name: "Magnesium", emoji: "🌙", time: .night),
    ]
}

enum MainGoal: String, Codable, CaseIterable, Identifiable {
    case loseFat, buildMuscle, recomp, maintain
    var id: String { rawValue }
    var title: String {
        switch self {
        case .loseFat: return "🔥 Lose fat"
        case .buildMuscle: return "💪 Build muscle"
        case .recomp: return "⚖️ Recomp (both)"
        case .maintain: return "🧘 Maintain & perform"
        }
    }
}

struct Profile: Codable {
    var name: String
    var avatar: String
    var areas: [Area]
    var calorieTarget: Int
    var proteinTarget: Int
    var waterTarget: Int
    var studyMinutesTarget: Int
    var workoutsPerWeek: Int
    var sleepTargetHours: Double = 8
    var supplements: [Supplement] = Supplement.defaults
    var age: Int? = nil
    var heightCm: Double? = nil
    var startWeightKg: Double? = nil
    var startBodyFat: Double? = nil
    var mainGoal: MainGoal = .recomp

    static let `default` = Profile(
        name: "Hero",
        avatar: "🧙‍♂️",
        areas: Area.allCases,
        calorieTarget: 2200,
        proteinTarget: 140,
        waterTarget: 8,
        studyMinutesTarget: 60,
        workoutsPerWeek: 4
    )

    init(name: String, avatar: String, areas: [Area], calorieTarget: Int, proteinTarget: Int,
         waterTarget: Int, studyMinutesTarget: Int, workoutsPerWeek: Int,
         sleepTargetHours: Double = 8, supplements: [Supplement] = Supplement.defaults) {
        self.name = name
        self.avatar = avatar
        self.areas = areas
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.waterTarget = waterTarget
        self.studyMinutesTarget = studyMinutesTarget
        self.workoutsPerWeek = workoutsPerWeek
        self.sleepTargetHours = sleepTargetHours
        self.supplements = supplements
    }

    enum CodingKeys: String, CodingKey {
        case name, avatar, areas, calorieTarget, proteinTarget, waterTarget
        case studyMinutesTarget, workoutsPerWeek, sleepTargetHours, supplements
        case age, heightCm, startWeightKg, startBodyFat, mainGoal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile.default
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar) ?? d.avatar
        areas = try c.decodeIfPresent([Area].self, forKey: .areas) ?? d.areas
        calorieTarget = try c.decodeIfPresent(Int.self, forKey: .calorieTarget) ?? d.calorieTarget
        proteinTarget = try c.decodeIfPresent(Int.self, forKey: .proteinTarget) ?? d.proteinTarget
        waterTarget = try c.decodeIfPresent(Int.self, forKey: .waterTarget) ?? d.waterTarget
        studyMinutesTarget = try c.decodeIfPresent(Int.self, forKey: .studyMinutesTarget) ?? d.studyMinutesTarget
        workoutsPerWeek = try c.decodeIfPresent(Int.self, forKey: .workoutsPerWeek) ?? d.workoutsPerWeek
        sleepTargetHours = try c.decodeIfPresent(Double.self, forKey: .sleepTargetHours) ?? 8
        supplements = try c.decodeIfPresent([Supplement].self, forKey: .supplements) ?? Supplement.defaults
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        startWeightKg = try c.decodeIfPresent(Double.self, forKey: .startWeightKg)
        startBodyFat = try c.decodeIfPresent(Double.self, forKey: .startBodyFat)
        mainGoal = try c.decodeIfPresent(MainGoal.self, forKey: .mainGoal) ?? .recomp
    }
}

// MARK: - Daily check-in (sleep, supplements, day rank)

struct DayLog: Codable {
    var sleepMinutes: Int? = nil
    var bedtime: Date? = nil
    var wakeTime: Date? = nil
    var supplementsTaken: [String] = []
    var finalScore: Int? = nil
    var finalRank: String? = nil
}

struct WeekGoal: Codable, Identifiable {
    var id = UUID()
    var text: String
    var done: Bool = false
}

struct WeekLog: Codable {
    var goals: [WeekGoal] = []
    var weightKg: Double? = nil
    var bodyFat: Double? = nil
    var feeling: Int? = nil          // 1...5
    var note: String = ""
    var finalScore: Int? = nil
    var finalRank: String? = nil
    var photoFile: String? = nil
}

struct BoxingSession: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var minutes: Int
    var note: String = ""
}

// MARK: - Gym

struct SetEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var reps: Int
    var weight: Double
}

struct ExerciseEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sets: [SetEntry]
}

struct Workout: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var title: String
    var exercises: [ExerciseEntry]
    var note: String = ""

    var setCount: Int {
        var total = 0
        for ex in exercises { total += ex.sets.count }
        return total
    }

    var volume: Double {
        var total = 0.0
        for ex in exercises {
            for s in ex.sets { total += Double(s.reps) * s.weight }
        }
        return total
    }

    /// A fresh copy (new ids, today's date) used for "repeat last workout".
    func asNew() -> Workout {
        let copied = exercises.map { ex in
            ExerciseEntry(name: ex.name, sets: ex.sets.map { SetEntry(reps: $0.reps, weight: $0.weight) })
        }
        return Workout(date: Date(), title: title, exercises: copied, note: "")
    }
}

struct BodyweightEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var kg: Double
}

// MARK: - Study

struct StudySession: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var subject: String
    var minutes: Int
    var note: String
}

// MARK: - Food

struct FoodEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var name: String
    var meal: MealType
    var calories: Int
    var protein: Int
}

// MARK: - Life

struct Habit: Codable, Identifiable {
    var id = UUID()
    var name: String
    var emoji: String
    var attribute: Attribute
    var completions: Set<String> = []
}

struct BossHit: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var amount: Double
}

/// A big goal you defeat over time. Every bit of progress is damage.
struct Boss: Codable, Identifiable {
    var id = UUID()
    var name: String
    var emoji: String
    var attribute: Attribute
    var target: Double
    var unit: String
    var hits: [BossHit] = []
    var deadline: Date? = nil
    var defeatedAt: Date? = nil

    var damage: Double { hits.reduce(0) { $0 + $1.amount } }
    var hpLeft: Double { max(0, target - damage) }
    var progress: Double { target > 0 ? min(1, damage / target) : 0 }
}

// MARK: - XP

struct XPEvent: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var amount: Int
    var attribute: Attribute
    var reason: String
    var sourceKey: String?
}

// MARK: - Everything that gets saved

struct AppData: Codable {
    var profile: Profile? = nil
    var workouts: [Workout] = []
    var bodyweight: [BodyweightEntry] = []
    var studySessions: [StudySession] = []
    var subjects: [String] = []
    var foods: [FoodEntry] = []
    var water: [String: Int] = [:]
    var habits: [Habit] = []
    var bosses: [Boss] = []
    var xpEvents: [XPEvent] = []
    var claimedQuests: [String: [String]] = [:]
    var seenAchievements: [String] = []
    var dayLogs: [String: DayLog] = [:]
    var boxing: [BoxingSession] = []
    var weekLogs: [String: WeekLog] = [:]

    init() {}

    enum CodingKeys: String, CodingKey {
        case profile, workouts, bodyweight, studySessions, subjects, foods, water
        case habits, bosses, xpEvents, claimedQuests, seenAchievements, dayLogs, boxing, weekLogs
    }

    // Tolerant decoding so future versions of the app can add fields without losing data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decodeIfPresent(Profile.self, forKey: .profile)
        workouts = try c.decodeIfPresent([Workout].self, forKey: .workouts) ?? []
        bodyweight = try c.decodeIfPresent([BodyweightEntry].self, forKey: .bodyweight) ?? []
        studySessions = try c.decodeIfPresent([StudySession].self, forKey: .studySessions) ?? []
        subjects = try c.decodeIfPresent([String].self, forKey: .subjects) ?? []
        foods = try c.decodeIfPresent([FoodEntry].self, forKey: .foods) ?? []
        water = try c.decodeIfPresent([String: Int].self, forKey: .water) ?? [:]
        habits = try c.decodeIfPresent([Habit].self, forKey: .habits) ?? []
        bosses = try c.decodeIfPresent([Boss].self, forKey: .bosses) ?? []
        xpEvents = try c.decodeIfPresent([XPEvent].self, forKey: .xpEvents) ?? []
        claimedQuests = try c.decodeIfPresent([String: [String]].self, forKey: .claimedQuests) ?? [:]
        seenAchievements = try c.decodeIfPresent([String].self, forKey: .seenAchievements) ?? []
        dayLogs = try c.decodeIfPresent([String: DayLog].self, forKey: .dayLogs) ?? [:]
        boxing = try c.decodeIfPresent([BoxingSession].self, forKey: .boxing) ?? []
        weekLogs = try c.decodeIfPresent([String: WeekLog].self, forKey: .weekLogs) ?? [:]
    }
}

// MARK: - Chart helper

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ExerciseLog: Identifiable {
    let id: UUID
    let date: Date
    let sets: [SetEntry]
}

struct SubjectTotal: Identifiable {
    let subject: String
    let minutes: Int
    var id: String { subject }
}
