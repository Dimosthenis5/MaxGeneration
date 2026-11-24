import SwiftUI

struct FoodView: View {
    @EnvironmentObject var store: Store
    @State private var day = Date()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    dayPicker
                    summary
                }

                Section("Water") {
                    waterRow
                }

                Section {
                    DisclosureGroup("🎚️ Adjust my targets") {
                        Stepper("🔥 Calories: \(store.profile.calorieTarget) kcal", value: profileBinding.calorieTarget, in: 1200...5000, step: 50)
                        Stepper("🥩 Protein: \(store.profile.proteinTarget) g", value: profileBinding.proteinTarget, in: 30...350, step: 5)
                        Stepper("💧 Water: \(store.profile.waterTarget) cups", value: profileBinding.waterTarget, in: 1...20)
                    }
                }

                ForEach(MealType.allCases) { meal in
                    mealSection(meal)
                }
            }
            .gameListStyle()
            .navigationTitle("Food")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddFoodSheet(day: day)
                    .environmentObject(store)
            }
        }
    }

    private var profileBinding: Binding<Profile> {
        Binding(get: { store.profile }, set: { store.data.profile = $0 })
    }

    private var dayPicker: some View {
        HStack {
            Button {
                if let d = Calendar.current.date(byAdding: .day, value: -1, to: day) { day = d }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            Spacer()
            Text(Calendar.current.isDateInToday(day) ? "Today" : day.formatted(date: .complete, time: .omitted))
                .font(.headline)
            Spacer()
            Button {
                if let d = Calendar.current.date(byAdding: .day, value: 1, to: day) { day = d }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(Calendar.current.isDateInToday(day))
        }
    }

    private var summary: some View {
        let p = store.profile
        let kcal = store.calories(on: day)
        let prot = store.protein(on: day)
        return VStack(spacing: 12) {
            macroRow(emoji: "🔥", title: "Calories", value: kcal, target: p.calorieTarget, unit: "kcal", color: .orange)
            macroRow(emoji: "🥩", title: "Protein", value: prot, target: p.proteinTarget, unit: "g", color: Attribute.vitality.color)
        }
        .padding(.vertical, 4)
    }

    private func macroRow(emoji: String, title: String, value: Int, target: Int, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(emoji) \(title)").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value) / \(target) \(unit)")
                    .font(.subheadline)
                    .foregroundColor(value > target && unit == "kcal" ? .red : .secondary)
            }
            ProgressBar(value: Double(value) / Double(max(1, target)), color: color, height: 8)
        }
    }

    private var waterRow: some View {
        let cups = store.water(on: day)
        let target = store.profile.waterTarget
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("💧 \(cups) / \(target) cups").font(.headline)
                Spacer()
                Button {
                    store.changeWater(on: day, by: -1)
                } label: {
                    Image(systemName: "minus.circle").font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(cups == 0)
                Button {
                    store.changeWater(on: day, by: 1)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 4) {
                ForEach(0..<max(target, cups), id: \.self) { i in
                    Image(systemName: i < cups ? "drop.fill" : "drop")
                        .foregroundColor(i < cups ? .cyan : .secondary)
                }
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func mealSection(_ meal: MealType) -> some View {
        let items = store.foods(on: day).filter { $0.meal == meal }
        Section {
            if items.isEmpty {
                Text("Nothing logged").font(.subheadline).foregroundColor(.secondary)
            }
            ForEach(items) { f in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.name)
                        Text("\(f.protein) g protein").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(f.calories) kcal").foregroundColor(.orange)
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { items[$0].id }
                for id in ids { store.deleteFood(id) }
            }
        } header: {
            HStack {
                Text("\(meal.emoji) \(meal.title)")
                Spacer()
                Text("\(items.reduce(0) { $0 + $1.calories }) kcal")
            }
        }
    }
}

struct AddFoodSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let day: Date

    @State private var name = ""
    @State private var meal = MealType.guess()
    @State private var calories = ""
    @State private var protein = ""

    private var entryDate: Date {
        Calendar.current.isDateInToday(day) ? Date() : day
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you eat?") {
                    TextField("e.g. Chicken & rice, Greek yogurt", text: $name)
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { m in
                            Text("\(m.emoji) \(m.title)").tag(m)
                        }
                    }
                    HStack {
                        TextField("Calories", text: $calories).keyboardType(.numberPad)
                        Text("kcal").foregroundColor(.secondary)
                    }
                    HStack {
                        TextField("Protein", text: $protein).keyboardType(.numberPad)
                        Text("g protein").foregroundColor(.secondary)
                    }
                }

                if !store.recentFoods.isEmpty {
                    Section {
                        ForEach(store.recentFoods) { f in
                            Button {
                                quickAdd(f)
                            } label: {
                                HStack {
                                    Text(f.name).foregroundColor(.primary)
                                    Spacer()
                                    Text("\(f.calories) kcal · \(f.protein) g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Attribute.vitality.color)
                                }
                            }
                        }
                    } header: {
                        Text("Quick add (recent)")
                    } footer: {
                        Text("Tap to log it again as \(meal.title.lowercased()).")
                    }
                }
            }
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        store.addFood(FoodEntry(
            date: entryDate,
            name: name.trimmingCharacters(in: .whitespaces),
            meal: meal,
            calories: Int(Num.parse(calories) ?? 0),
            protein: Int(Num.parse(protein) ?? 0)
        ))
        dismiss()
    }

    private func quickAdd(_ f: FoodEntry) {
        store.addFood(FoodEntry(date: entryDate, name: f.name, meal: meal, calories: f.calories, protein: f.protein))
        dismiss()
    }
}
