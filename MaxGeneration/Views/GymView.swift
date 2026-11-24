import SwiftUI
import Charts

struct GymView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Workout? = nil
    @State private var showBoxing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    weekHeader
                }

                Section("Start training") {
                    Button {
                        editing = Workout(date: Date(), title: "", exercises: [])
                    } label: {
                        Label("New gym workout", systemImage: "dumbbell.fill")
                            .font(.headline)
                    }
                    Button {
                        showBoxing = true
                    } label: {
                        Label("Log boxing session", systemImage: "figure.boxing")
                            .font(.headline)
                    }
                    ForEach(store.workoutTemplates()) { t in
                        Button {
                            editing = t.asNew()
                        } label: {
                            Label("Repeat \(t.title)", systemImage: "arrow.clockwise.circle")
                        }
                    }
                }

                Section("Progress") {
                    NavigationLink {
                        ExerciseListView()
                    } label: {
                        Label("Exercises & PRs", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink {
                        BodyweightView()
                    } label: {
                        Label("Bodyweight", systemImage: "scalemass.fill")
                    }
                }

                if !store.data.boxing.isEmpty {
                    Section("🥊 Boxing") {
                        ForEach(store.data.boxing) { b in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Boxing · \(b.minutes) min").font(.headline)
                                    if !b.note.isEmpty {
                                        Text(b.note).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(b.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { store.data.boxing[$0].id }
                            for id in ids { store.deleteBoxing(id) }
                        }
                    }
                }

                Section("Gym history") {
                    if store.data.workouts.isEmpty {
                        Text("No workouts yet. Your first one unlocks an achievement!")
                            .foregroundColor(.secondary)
                    }
                    ForEach(store.data.workouts) { w in
                        Button {
                            editing = w
                        } label: {
                            WorkoutRow(workout: w)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.data.workouts[$0].id }
                        for id in ids { store.deleteWorkout(id) }
                    }
                }
            }
            .gameListStyle()
            .navigationTitle("Train")
            .sheet(item: $editing) { w in
                WorkoutEditor(workout: w)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showBoxing) {
                BoxingSheet().environmentObject(store)
            }
        }
    }

    private var weekHeader: some View {
        let done = store.workoutsThisWeek()
        let goal = store.profile.workoutsPerWeek
        let info = Leveling.attributeInfo(store.xp(.strength))
        return HStack(spacing: 16) {
            ZStack {
                ProgressRing(value: Double(done) / Double(max(1, goal)), color: Attribute.strength.color, lineWidth: 10)
                VStack(spacing: 0) {
                    Text("\(done)/\(goal)").font(.headline)
                    Text("week").font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 6) {
                Text("💪 Strength Lv \(info.level)").font(.headline)
                ProgressBar(value: info.fraction, color: Attribute.strength.color, height: 8)
                Text("Gym gives 20–80 XP, boxing 15 XP + 1 XP per 2 min. Every PR gives +25.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.title).font(.headline)
                Spacer()
                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(workout.exercises.map { $0.name }.joined(separator: " · "))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text("\(workout.setCount) sets · \(Num.text(workout.volume)) kg volume")
                .font(.caption2)
                .foregroundColor(Attribute.strength.color)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Editor

struct DraftSet: Identifiable {
    var id = UUID()
    var weight: String
    var reps: String
}

struct DraftExercise: Identifiable {
    var id = UUID()
    var name: String
    var sets: [DraftSet]
}

struct WorkoutEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let originalID: UUID
    @State private var title: String
    @State private var date: Date
    @State private var drafts: [DraftExercise]
    @State private var customName = ""
    @State private var askCustom = false

    static let common = [
        "Bench Press", "Squat", "Deadlift", "Overhead Press", "Pull-up", "Barbell Row",
        "Incline Dumbbell Press", "Lat Pulldown", "Romanian Deadlift", "Leg Press",
        "Bicep Curl", "Tricep Pushdown", "Lateral Raise", "Dips", "Hip Thrust", "Calf Raise",
    ]

    init(workout: Workout) {
        originalID = workout.id
        _title = State(initialValue: workout.title)
        _date = State(initialValue: workout.date)
        _drafts = State(initialValue: workout.exercises.map { ex in
            DraftExercise(name: ex.name, sets: ex.sets.map { DraftSet(weight: Num.text($0.weight), reps: String($0.reps)) })
        })
    }

    private var isExisting: Bool { store.data.workouts.contains { $0.id == originalID } }

    private var suggestions: [String] {
        var out = store.exerciseNames
        for c in WorkoutEditor.common where !out.contains(where: { $0.lowercased() == c.lowercased() }) {
            out.append(c)
        }
        return out
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Push Day, Legs)", text: $title)
                    DatePicker("Date", selection: $date)
                }

                ForEach($drafts) { $ex in
                    Section {
                        TextField("Exercise name", text: $ex.name)
                            .font(.headline)
                        ForEach($ex.sets) { $entry in
                            SetRow(number: (ex.sets.firstIndex(where: { $0.id == entry.id }) ?? 0) + 1, entry: $entry)
                        }
                        .onDelete { offsets in
                            $ex.wrappedValue.sets.remove(atOffsets: offsets)
                        }
                        HStack {
                            Button {
                                let last = ex.sets.last
                                $ex.wrappedValue.sets.append(DraftSet(weight: last?.weight ?? "", reps: last?.reps ?? ""))
                            } label: {
                                Label("Add set", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                            Spacer()
                            Button(role: .destructive) {
                                let id = ex.id
                                drafts.removeAll { $0.id == id }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.subheadline)
                    }
                }

                Section {
                    Menu {
                        Button("Custom exercise…") { askCustom = true }
                        ForEach(suggestions, id: \.self) { name in
                            Button(name) { addExercise(name) }
                        }
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                } footer: {
                    Text("Tip: leave reps empty to skip a set. Weight 0 is fine for bodyweight moves. Swipe a set left to delete it.")
                }

                if isExisting {
                    Section {
                        Button("Delete workout", role: .destructive) {
                            store.deleteWorkout(originalID)
                            dismiss()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isExisting ? "Edit workout" : "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(buildExercises().isEmpty)
                }
            }
            .alert("Custom exercise", isPresented: $askCustom) {
                TextField("Exercise name", text: $customName)
                Button("Add") {
                    let n = customName.trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty { addExercise(n) }
                    customName = ""
                }
                Button("Cancel", role: .cancel) { customName = "" }
            }
        }
    }

    private func addExercise(_ name: String) {
        // Prefill with the last sets you did for this exercise.
        let previous = store.history(for: name).first?.sets ?? []
        let sets: [DraftSet]
        if previous.isEmpty {
            sets = [DraftSet(weight: "", reps: ""), DraftSet(weight: "", reps: ""), DraftSet(weight: "", reps: "")]
        } else {
            sets = previous.map { DraftSet(weight: Num.text($0.weight), reps: String($0.reps)) }
        }
        drafts.append(DraftExercise(name: name, sets: sets))
    }

    private func buildExercises() -> [ExerciseEntry] {
        drafts.compactMap { d -> ExerciseEntry? in
            let name = d.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            let sets = d.sets.compactMap { s -> SetEntry? in
                guard let reps = Int(s.reps.trimmingCharacters(in: .whitespaces)), reps > 0 else { return nil }
                return SetEntry(reps: reps, weight: max(0, Num.parse(s.weight) ?? 0))
            }
            return sets.isEmpty ? nil : ExerciseEntry(name: name, sets: sets)
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let workout = Workout(
            id: originalID,
            date: date,
            title: cleanTitle.isEmpty ? "Workout" : cleanTitle,
            exercises: buildExercises(),
            note: ""
        )
        store.saveWorkout(workout)
        dismiss()
    }
}

struct SetRow: View {
    let number: Int
    @Binding var entry: DraftSet

    var body: some View {
        HStack(spacing: 8) {
            Text("Set \(number)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            TextField("0", text: $entry.weight)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
            Text("kg").foregroundColor(.secondary)
            Text("×").foregroundColor(.secondary)
            TextField("0", text: $entry.reps)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 60)
            Text("reps").foregroundColor(.secondary)
        }
    }
}

// MARK: - Progress

struct ExerciseListView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List {
            if store.exerciseNames.isEmpty {
                Text("Log a workout to see your exercises here.")
                    .foregroundColor(.secondary)
            }
            ForEach(store.exerciseNames, id: \.self) { name in
                NavigationLink {
                    ExerciseDetailView(name: name)
                } label: {
                    HStack {
                        Text(name)
                        Spacer()
                        Text("e1RM \(Num.text(store.bestE1RM(name))) kg")
                            .font(.caption)
                            .foregroundColor(Attribute.strength.color)
                    }
                }
            }
        }
        .gameListStyle()
        .navigationTitle("Exercises")
    }
}

struct ExerciseDetailView: View {
    @EnvironmentObject var store: Store
    let name: String

    var body: some View {
        let points = store.progress(for: name)
        let logs = store.history(for: name)
        List {
            Section {
                if points.count < 2 {
                    Text("Log this exercise in 2+ workouts to see your trend line.")
                        .foregroundColor(.secondary)
                }
                Chart(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value("kg", p.value))
                        .foregroundStyle(Attribute.strength.color)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", p.date), y: .value("kg", p.value))
                        .foregroundStyle(Attribute.strength.color)
                }
                .frame(height: 220)
                .padding(.vertical, 8)
            } header: {
                Text("Estimated 1-rep max (kg)")
            } footer: {
                Text("Best estimated max: \(Num.text(store.bestE1RM(name))) kg. Beat it to earn a PR.")
            }

            Section("History") {
                ForEach(logs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.bold())
                        Text(log.sets.map { "\(Num.text($0.weight))×\($0.reps)" }.joined(separator: "  "))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .gameListStyle()
        .navigationTitle(name)
    }
}

struct BodyweightView: View {
    @EnvironmentObject var store: Store
    @State private var input = ""

    var body: some View {
        let points = store.data.bodyweight.map { ChartPoint(date: $0.date, value: $0.kg) }.sorted { $0.date < $1.date }
        List {
            Section("Log weigh-in") {
                HStack {
                    TextField("Weight", text: $input)
                        .keyboardType(.decimalPad)
                    Text("kg").foregroundColor(.secondary)
                    Button("Add +5 XP") {
                        if let kg = Num.parse(input), kg > 0 {
                            store.addBodyweight(kg)
                            input = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(Num.parse(input) == nil)
                }
            }
            if points.count >= 2 {
                Section("Trend") {
                    Chart(points) { p in
                        LineMark(x: .value("Date", p.date), y: .value("kg", p.value))
                            .foregroundStyle(Attribute.vitality.color)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", p.date), y: .value("kg", p.value))
                            .foregroundStyle(Attribute.vitality.color)
                    }
                    .chartYScale(domain: yDomain(points))
                    .frame(height: 200)
                    .padding(.vertical, 8)
                }
            }
            Section("History") {
                ForEach(store.data.bodyweight) { e in
                    HStack {
                        Text(e.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text("\(Num.text(e.kg)) kg").bold()
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { store.data.bodyweight[$0].id }
                    for id in ids { store.deleteBodyweight(id) }
                }
            }
        }
        .gameListStyle()
        .navigationTitle("Bodyweight")
    }

    private func yDomain(_ points: [ChartPoint]) -> ClosedRange<Double> {
        let values = points.map { $0.value }
        let lo = (values.min() ?? 0) - 2
        let hi = (values.max() ?? 100) + 2
        return max(0, lo)...max(hi, lo + 1)
    }
}

struct BoxingSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 60
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("⏱️ Duration: \(minutes) min", value: $minutes, in: 5...240, step: 5)
                    DatePicker("When", selection: $date)
                    TextField("Note (sparring, pads, bag work…)", text: $note)
                }
                Section {
                    Text("This session is worth +\(min(80, 15 + minutes / 2)) XP 💪")
                        .foregroundColor(Attribute.strength.color)
                }
            }
            .navigationTitle("🥊 Boxing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addBoxing(BoxingSession(date: date, minutes: minutes, note: note.trimmingCharacters(in: .whitespaces)))
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
