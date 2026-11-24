import SwiftUI

struct StarterHabit: Identifiable, Hashable {
    let name: String
    let emoji: String
    let attribute: Attribute
    var id: String { name }

    static let suggestions: [StarterHabit] = [
        StarterHabit(name: "In bed by 23:30", emoji: "🛏️", attribute: .discipline),
        StarterHabit(name: "Read 20 minutes", emoji: "📖", attribute: .intellect),
        StarterHabit(name: "Meditate 10 minutes", emoji: "🧘", attribute: .discipline),
        StarterHabit(name: "No junk food", emoji: "🥗", attribute: .vitality),
        StarterHabit(name: "10k steps", emoji: "🚶", attribute: .strength),
        StarterHabit(name: "Wake up before 8", emoji: "⏰", attribute: .discipline),
        StarterHabit(name: "No phone first hour", emoji: "📵", attribute: .discipline),
        StarterHabit(name: "Stretch / mobility", emoji: "🤸", attribute: .strength),
    ]
}

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var step = 0
    @State private var name = ""
    @State private var avatar = "🧙‍♂️"
    @State private var areas: Set<Area> = Set(Area.allCases)
    @State private var calories = 2200
    @State private var protein = 140
    @State private var water = 8
    @State private var studyMinutes = 60
    @State private var workouts = 4
    @State private var habits: Set<String> = ["Read 20 minutes"]
    @State private var age = 20
    @State private var height = ""
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var goal = MainGoal.recomp
    @State private var sleepHours = 8.0

    private let lastStep = 5

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0...lastStep, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Theme.accent : Color.white.opacity(0.15))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $step) {
                    welcome.tag(0)
                    identity.tag(1)
                    details.tag(2)
                    areaStep.tag(3)
                    targets.tag(4)
                    habitStep.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Button(step < lastStep ? "Next" : "Begin your quest ⚔️") {
                    if step < lastStep {
                        withAnimation { step += 1 }
                    } else {
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("⚔️").font(.system(size: 90))
            Text("MaxGeneration")
                .font(.system(size: 40, weight: .black, design: .rounded).italic())
            Text("Your life is the game.\nTrain, study, eat well and build habits to earn XP, level up your hero and defeat your biggest goals.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
            Spacer()
            Spacer()
        }
    }

    private var identity: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create your hero").font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?").font(.headline)
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick your avatar").font(.headline)
                    EmojiPicker(selection: $avatar, options: Emojis.avatars)
                }
                HStack {
                    Spacer()
                    Text(avatar).font(.system(size: 100))
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your details").font(.largeTitle.bold())
                Text("This is your starting point. Everything stays private on your phone.")
                    .foregroundColor(.secondary)
                VStack(spacing: 14) {
                    Stepper("🎂 Age: \(age)", value: $age, in: 10...99)
                    detailField("📏 Height", text: $height, unit: "cm")
                    detailField("⚖️ Weight", text: $weight, unit: "kg")
                    detailField("📉 Body fat", text: $bodyFat, unit: "%")
                }
                .card()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Main goal").font(.headline)
                    ForEach(MainGoal.allCases) { g in
                        Button {
                            goal = g
                        } label: {
                            HStack {
                                Text(g.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: goal == g ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(goal == g ? Theme.accent : .secondary)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(goal == g ? 0.1 : 0.04)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
    }

    private func detailField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit).foregroundColor(.secondary).frame(width: 30, alignment: .leading)
        }
    }

    private var areaStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What do you want to level up?").font(.largeTitle.bold())
                Text("Each area gets its own tab. You can change this later in Settings.")
                    .foregroundColor(.secondary)
                ForEach(Area.allCases) { area in
                    let on = areas.contains(area)
                    Button {
                        if on { areas.remove(area) } else { areas.insert(area) }
                    } label: {
                        HStack {
                            Text(area.emoji).font(.title)
                            Text(area.title).font(.headline)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(on ? Theme.accent : .secondary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
    }

    private var targets: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Set your daily targets").font(.largeTitle.bold())
                Text("Quests are built from these. Be honest, and make them reachable.")
                    .foregroundColor(.secondary)
                VStack(spacing: 14) {
                    Stepper("😴 Sleep: \(Num.text(sleepHours)) h / night", value: $sleepHours, in: 5...11, step: 0.5)
                    Text("💊 Supplements: Multivitamin, Omega-3, Creatine and Magnesium (night) are set up. Edit them in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if areas.contains(.gym) {
                        Stepper("🥊 Training sessions / week: \(workouts)", value: $workouts, in: 1...7)
                    }
                    if areas.contains(.study) {
                        Stepper("📚 Study: \(studyMinutes) min / day", value: $studyMinutes, in: 15...600, step: 15)
                    }
                    if areas.contains(.food) {
                        Stepper("🔥 Calories: \(calories) kcal", value: $calories, in: 1200...5000, step: 50)
                        Stepper("🥩 Protein: \(protein) g", value: $protein, in: 30...350, step: 5)
                        Stepper("💧 Water: \(water) glasses", value: $water, in: 1...20)
                    }
                    if !areas.contains(.gym) && !areas.contains(.study) && !areas.contains(.food) {
                        Text("No targets needed for the areas you picked.").foregroundColor(.secondary)
                    }
                }
                .card()
            }
            .padding(24)
        }
    }

    private var habitStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Starter habits").font(.largeTitle.bold())
                Text("Tick off habits daily for XP and streaks. Pick a few now, and add your own later.")
                    .foregroundColor(.secondary)
                ForEach(StarterHabit.suggestions) { h in
                    let on = habits.contains(h.name)
                    Button {
                        if on { habits.remove(h.name) } else { habits.insert(h.name) }
                    } label: {
                        HStack {
                            Text(h.emoji).font(.title2)
                            VStack(alignment: .leading) {
                                Text(h.name).font(.headline)
                                Text("\(h.attribute.emoji) \(h.attribute.title)")
                                    .font(.caption).foregroundColor(h.attribute.color)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(on ? Theme.accent : .secondary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
    }

    // MARK: Finish

    private func finish() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let chosenAreas = Area.allCases.filter { areas.contains($0) }
        let profile = Profile(
            name: trimmed.isEmpty ? "Hero" : trimmed,
            avatar: avatar,
            areas: chosenAreas.isEmpty ? [.life] : chosenAreas,
            calorieTarget: calories,
            proteinTarget: protein,
            waterTarget: water,
            studyMinutesTarget: studyMinutes,
            workoutsPerWeek: workouts,
            sleepTargetHours: sleepHours
        )
        var withDetails = profile
        withDetails.age = age
        withDetails.heightCm = Num.parse(height)
        withDetails.startWeightKg = Num.parse(weight)
        withDetails.startBodyFat = Num.parse(bodyFat)
        withDetails.mainGoal = goal
        let starter = StarterHabit.suggestions
            .filter { habits.contains($0.name) }
            .map { Habit(name: $0.name, emoji: $0.emoji, attribute: $0.attribute) }
        store.finishOnboarding(profile: withDetails, habits: starter)
        if let w = withDetails.startWeightKg, w > 0 { store.addBodyweight(w) }
    }
}
