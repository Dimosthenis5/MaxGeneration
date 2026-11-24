import SwiftUI
import UniformTypeIdentifiers

struct BadgesView: View {
    @EnvironmentObject var store: Store
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        let unlocked = Achievement.all.filter { store.isUnlocked($0) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(unlocked) of \(Achievement.all.count) unlocked")
                    .font(.headline)
                    .foregroundColor(.secondary)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Achievement.all) { a in
                        let on = store.isUnlocked(a)
                        VStack(spacing: 6) {
                            Text(on ? a.emoji : "🔒")
                                .font(.system(size: 36))
                                .grayscale(on ? 0 : 1)
                            Text(a.title)
                                .font(.caption.bold())
                                .multilineTextAlignment(.center)
                            Text(a.detail)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 130)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(on ? Theme.accent.opacity(0.18) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(on ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                        .opacity(on ? 1 : 0.6)
                    }
                }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle("Achievements")
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderTime") private var reminderTime: Double = 20 * 3600
    @State private var importing = false
    @State private var importResult: String? = nil
    @State private var confirmReset = false
    @AppStorage("soundOn") private var soundOn = true
    @State private var newSuppName = ""
    @State private var newSuppEmoji = "💊"
    @State private var newSuppTime = SupplementTime.anytime

    private var profile: Binding<Profile> {
        Binding(get: { store.profile }, set: { store.data.profile = $0 })
    }

    private func areaBinding(_ area: Area) -> Binding<Bool> {
        Binding(
            get: { store.profile.areas.contains(area) },
            set: { on in
                var p = store.profile
                if on {
                    if !p.areas.contains(area) { p.areas.append(area) }
                } else {
                    p.areas.removeAll { $0 == area }
                }
                store.data.profile = p
            }
        )
    }

    private var reminderDate: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(reminderTime) },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                reminderTime = Double((c.hour ?? 20) * 3600 + (c.minute ?? 0) * 60)
                if reminderOn { scheduleReminder() }
            }
        )
    }

    var body: some View {
        Form {
            Section("Hero") {
                TextField("Name", text: profile.name)
                EmojiPicker(selection: profile.avatar, options: Emojis.avatars)
            }

            Section("My details") {
                Stepper("🎂 Age: \(store.profile.age ?? 20)", value: Binding(
                    get: { store.profile.age ?? 20 },
                    set: { v in var p = store.profile; p.age = v; store.data.profile = p }
                ), in: 10...99)
                numberRow("📏 Height", unit: "cm", value: profile.heightCm)
                numberRow("⚖️ Starting weight", unit: "kg", value: profile.startWeightKg)
                numberRow("📉 Starting body fat", unit: "%", value: profile.startBodyFat)
                Picker("Main goal", selection: profile.mainGoal) {
                    ForEach(MainGoal.allCases) { g in Text(g.title).tag(g) }
                }
            }

            Section {
                ForEach(store.profile.supplements) { s in
                    HStack {
                        Text(s.emoji)
                        Text(s.name)
                        Spacer()
                        Text("\(s.time.emoji) \(s.time.title)").font(.caption).foregroundColor(.secondary)
                    }
                }
                .onDelete { offsets in
                    var p = store.profile
                    p.supplements.remove(atOffsets: offsets)
                    store.data.profile = p
                }
                HStack {
                    TextField("💊", text: $newSuppEmoji).frame(width: 36)
                    TextField("Add supplement (e.g. Vitamin D)", text: $newSuppName)
                }
                Picker("When", selection: $newSuppTime) {
                    ForEach(SupplementTime.allCases) { t in Text("\(t.emoji) \(t.title)").tag(t) }
                }
                Button("Add supplement") {
                    let name = newSuppName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    var p = store.profile
                    p.supplements.append(Supplement(name: name, emoji: newSuppEmoji.isEmpty ? "💊" : newSuppEmoji, time: newSuppTime))
                    store.data.profile = p
                    newSuppName = ""
                }
                .disabled(newSuppName.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Supplements")
            } footer: {
                Text("Swipe left to remove one.")
            }

            Section {
                ForEach(Area.allCases) { area in
                    Toggle("\(area.emoji) \(area.title)", isOn: areaBinding(area))
                }
            } header: {
                Text("Areas")
            } footer: {
                Text("Turning an area off hides its tab and quests. Your data stays saved.")
            }

            Section("Targets") {
                Stepper("😴 Sleep: \(Num.text(store.profile.sleepTargetHours)) h", value: profile.sleepTargetHours, in: 5...11, step: 0.5)
                Stepper("🥊 Training / week: \(store.profile.workoutsPerWeek)", value: profile.workoutsPerWeek, in: 1...7)
                Stepper("📚 Study: \(store.profile.studyMinutesTarget) min", value: profile.studyMinutesTarget, in: 15...600, step: 15)
                Stepper("🔥 Calories: \(store.profile.calorieTarget)", value: profile.calorieTarget, in: 1200...5000, step: 50)
                Stepper("🥩 Protein: \(store.profile.proteinTarget) g", value: profile.proteinTarget, in: 30...350, step: 5)
                Stepper("💧 Water: \(store.profile.waterTarget) cups", value: profile.waterTarget, in: 1...20)
            }

            Section {
                Toggle("🔊 Sound effects", isOn: $soundOn)
                    .onChange(of: soundOn) { on in if on { SoundFX.play(.claim) } }
                Toggle("Daily reminder", isOn: $reminderOn)
                    .onChange(of: reminderOn) { on in
                        if on { scheduleReminder() } else { Reminders.cancel() }
                    }
                if reminderOn {
                    DatePicker("Time", selection: reminderDate, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Sound & notifications")
            }

            Section {
                ShareLink(item: store.exportFile()) {
                    Label("Export backup", systemImage: "square.and.arrow.up")
                }
                Button {
                    importing = true
                } label: {
                    Label("Import backup", systemImage: "square.and.arrow.down")
                }
                if let r = importResult {
                    Text(r).font(.caption).foregroundColor(.secondary)
                }
            } header: {
                Text("Your data")
            } footer: {
                Text("Everything is stored only on this iPhone. Export a backup now and then (to Files or iCloud Drive) so you never lose progress. Progress photos stay in your camera roll / the app and are not in the backup file.")
            }

            Section("Stats") {
                LabeledContent("Total XP", value: "\(store.totalXP)")
                LabeledContent("Level", value: "\(store.level)")
                LabeledContent("Best streak", value: "\(store.bestStreak) days")
                LabeledContent("Workouts", value: "\(store.data.workouts.count)")
                LabeledContent("Study time", value: "\(store.totalStudyMinutes / 60)h \(store.totalStudyMinutes % 60)m")
                LabeledContent("Meals logged", value: "\(store.data.foods.count)")
            }

            Section {
                Button("Reset everything", role: .destructive) { confirmReset = true }
            }
        }
        .gameListStyle()
        .navigationTitle("Settings")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importResult = store.importData(from: url) ? "✅ Backup restored." : "⚠️ That file isn't a MaxGeneration backup."
            case .failure:
                importResult = "⚠️ Couldn't open that file."
            }
        }
        .confirmationDialog("Delete all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { store.resetAll() }
        } message: {
            Text("This wipes your hero, XP and all logs. It can't be undone, so export a backup first.")
        }
    }

    private func numberRow(_ title: String, unit: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("–", text: Binding(
                get: { value.wrappedValue.map { Num.text($0) } ?? "" },
                set: { value.wrappedValue = Num.parse($0) }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            Text(unit).foregroundColor(.secondary)
        }
    }

    private func scheduleReminder() {
        let total = Int(reminderTime)
        Reminders.schedule(hour: total / 3600, minute: (total % 3600) / 60, name: store.profile.name)
    }
}
