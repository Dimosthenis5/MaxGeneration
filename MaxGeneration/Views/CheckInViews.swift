import SwiftUI
import Charts
import PhotosUI

struct ResultPayload: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let result: DayScore
}

// MARK: - Home: daily check-in (sleep first)

struct DailyCheckInCard: View {
    @EnvironmentObject var store: Store
    @State private var showSleep = false
    @State private var payload: ResultPayload? = nil

    var body: some View {
        let log = store.dayLog()
        let live = store.dayScore()
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today's run").font(.headline)
                Spacer()
                Text("Live rank")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(live.rank)
                    .font(.system(size: 22, weight: .black, design: .rounded).italic())
                    .foregroundColor(Rank.color(live.rank))
                Text("\(live.score)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }

            // Sleep
            Button {
                showSleep = true
            } label: {
                HStack(spacing: 12) {
                    Text("😴").font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        if let mins = log.sleepMinutes {
                            Text("Slept \(Store.hoursText(mins))").font(.subheadline.bold())
                            ProgressBar(value: Double(mins) / Double(max(1, store.sleepTargetMinutes)),
                                        color: Attribute.vitality.color, height: 6)
                        } else {
                            Text("Log last night's sleep").font(.subheadline.bold())
                            Text("Goal: \(Num.text(store.profile.sleepTargetHours))h · +15 XP, +15 more if you hit it")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: log.sleepMinutes == nil ? "plus.circle.fill" : "pencil.circle")
                        .font(.title2)
                        .foregroundColor(Theme.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Supplements
            if !store.profile.supplements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supplements · \(store.supplementsTakenCount()) / \(store.profile.supplements.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.profile.supplements) { s in
                                SupplementChip(supplement: s)
                            }
                        }
                    }
                }
            }

            Button {
                let result = store.finishDay()
                payload = ResultPayload(title: "DAY CLEAR!",
                                        subtitle: Date().formatted(date: .complete, time: .omitted),
                                        result: result)
            } label: {
                Label(log.finalRank == nil ? "Finish day & get my rank" : "Update today's rank (\(log.finalRank ?? ""))",
                      systemImage: "flag.checkered")
                    .font(.subheadline.bold())
            }
            .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.15, green: 0.4, blue: 1.0)))

            rankHistory
        }
        .card()
        .sheet(isPresented: $showSleep) {
            SleepSheet().environmentObject(store)
        }
        .fullScreenCover(item: $payload) { p in
            ResultsView(title: p.title, subtitle: p.subtitle, result: p.result, bonusXP: Rank.bonus(p.result.rank))
        }
    }

    private var rankHistory: some View {
        HStack(spacing: 6) {
            ForEach(store.rankHistory(7)) { d in
                VStack(spacing: 3) {
                    Text(d.rank ?? "–")
                        .font(.system(size: 15, weight: .black, design: .rounded).italic())
                        .foregroundColor(d.rank.map { Rank.color($0) } ?? .secondary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    Text(d.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct SupplementChip: View {
    @EnvironmentObject var store: Store
    let supplement: Supplement

    var body: some View {
        let taken = store.isTaken(supplement)
        Button {
            store.toggleSupplement(supplement)
        } label: {
            HStack(spacing: 6) {
                Text(supplement.emoji)
                VStack(alignment: .leading, spacing: 0) {
                    Text(supplement.name).font(.caption.bold())
                    Text(supplement.time.title).font(.system(size: 9)).foregroundColor(.secondary)
                }
                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(taken ? Attribute.vitality.color : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(taken ? Attribute.vitality.color.opacity(0.2) : Color.white.opacity(0.06)))
            .overlay(Capsule().stroke(taken ? Attribute.vitality.color : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sleep entry

struct SleepSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var bed: Date
    @State private var wake: Date
    @State private var day = Date()

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        _bed = State(initialValue: cal.date(bySettingHour: 23, minute: 30, second: 0, of: today) ?? Date())
        _wake = State(initialValue: cal.date(bySettingHour: 7, minute: 30, second: 0, of: today) ?? Date())
    }

    var body: some View {
        let minutes = Store.sleepMinutes(bed: bed, wake: wake)
        let target = store.sleepTargetMinutes
        NavigationStack {
            Form {
                Section {
                    DatePicker("🌙 Went to bed", selection: $bed, displayedComponents: .hourAndMinute)
                    DatePicker("☀️ Woke up", selection: $wake, displayedComponents: .hourAndMinute)
                    DatePicker("Morning of", selection: $day, in: ...Date(), displayedComponents: .date)
                } footer: {
                    Text("Copy the times from your Galaxy Fit. Samsung doesn't let iPhone apps read its data directly.")
                }
                Section {
                    HStack {
                        Text("Total sleep")
                        Spacer()
                        Text(Store.hoursText(minutes))
                            .font(.title2.bold())
                            .foregroundColor(minutes >= target ? Attribute.vitality.color : .orange)
                    }
                    ProgressBar(value: Double(minutes) / Double(max(1, target)), color: Attribute.vitality.color, height: 10)
                    Text(minutes >= target ? "Goal hit! +30 XP" : "\(Store.hoursText(max(0, target - minutes))) short of your goal · +15 XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("Last 7 nights") {
                    Chart {
                        ForEach(store.sleepLastDays(7)) { p in
                            BarMark(x: .value("Day", p.date, unit: .day), y: .value("Hours", p.value))
                                .foregroundStyle(p.value * 60 >= Double(target) ? Attribute.vitality.color : Color.orange.opacity(0.7))
                                .cornerRadius(5)
                        }
                        RuleMark(y: .value("Goal", Double(target) / 60))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .frame(height: 150)
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.logSleep(day: day, bed: bed, wake: wake)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Home: week card

struct WeekCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let log = store.weekLog()
        let live = store.weekScore()
        let done = log.goals.filter { $0.done }.count
        NavigationLink {
            WeekView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("This week").font(.headline)
                    Spacer()
                    Text("Week rank")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(live.rank)
                        .font(.system(size: 22, weight: .black, design: .rounded).italic())
                        .foregroundColor(Rank.color(live.rank))
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
                if store.lastWeekNeedsCheckIn {
                    Text("📏 Last week's check-in is waiting. Log your body stats to get its rank.")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }
                if log.goals.isEmpty {
                    Text("🎯 Set this week's goals so you know where you're heading.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ProgressBar(value: Double(done) / Double(log.goals.count), color: Attribute.discipline.color, height: 8)
                    Text("\(done) / \(log.goals.count) goals done")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Week screen

struct WeekView: View {
    @EnvironmentObject var store: Store
    @State private var newGoal = ""
    @State private var checkInWeek: Date? = nil
    @State private var payload: ResultPayload? = nil
    @State private var viewerStart: PhotoViewerStart? = nil

    var body: some View {
        let log = store.weekLog()
        let live = store.weekScore()
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weekTitle(store.weekStart()))
                            .font(.headline)
                        Text("Score so far: \(live.score) / 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(live.rank)
                        .font(.system(size: 40, weight: .black, design: .rounded).italic())
                        .foregroundColor(Rank.color(live.rank))
                }
                ForEach(live.lines) { line in
                    HStack {
                        Text("\(line.emoji) \(line.title)")
                        Spacer()
                        Text(line.detail).font(.caption).foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text("Week rank = 50% your daily ranks + 25% week goals + 15% training sessions + 10% body check-in.")
            }

            if store.lastWeekNeedsCheckIn {
                Section {
                    Button {
                        checkInWeek = store.lastWeekDate
                    } label: {
                        Label("Do last week's check-in", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }

            Section {
                ForEach(log.goals) { g in
                    Button {
                        store.toggleWeekGoal(g)
                    } label: {
                        HStack {
                            Image(systemName: g.done ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(g.done ? Attribute.discipline.color : .secondary)
                                .font(.title3)
                            Text(g.text)
                                .strikethrough(g.done)
                                .foregroundColor(g.done ? .secondary : .primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let ids = offsets.map { log.goals[$0].id }
                    for id in ids { store.deleteWeekGoal(id) }
                }
                HStack {
                    TextField("e.g. Train 4x, sleep 7h+ every night", text: $newGoal)
                        .onSubmit { addGoal() }
                    Button("Add") { addGoal() }
                        .buttonStyle(.borderless)
                        .disabled(newGoal.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("🎯 This week's goals · +25 XP each")
            } footer: {
                Text("Set these on Monday. Swipe left to delete one.")
            }

            Section {
                Button {
                    checkInWeek = Date()
                } label: {
                    Label(log.finalRank == nil ? "End-of-week check-in" : "Redo this week's check-in (\(log.finalRank ?? ""))",
                          systemImage: "flag.checkered.2.crossed")
                        .font(.headline)
                }
            } footer: {
                Text("On Sunday, log your weight, body fat % and how the week felt to get your week rank (double rank XP).")
            }

            photoGallery

            history
        }
        .gameListStyle()
        .navigationTitle("Week")
        .sheet(item: Binding(
            get: { checkInWeek.map { WeekSheetTarget(date: $0) } },
            set: { checkInWeek = $0?.date }
        )) { target in
            WeekCheckInSheet(week: target.date) { result in
                payload = ResultPayload(title: "WEEK CLEAR!", subtitle: weekTitle(store.weekStart(target.date)), result: result)
            }
            .environmentObject(store)
        }
        .fullScreenCover(item: $payload) { p in
            ResultsView(title: p.title, subtitle: p.subtitle, result: p.result, bonusXP: Rank.bonus(p.result.rank) * 2)
        }
        .fullScreenCover(item: $viewerStart) { start in
            PhotoViewer(photos: store.progressPhotos, startID: start.id)
        }
    }

    @ViewBuilder
    private var photoGallery: some View {
        let photos = store.progressPhotos
        if !photos.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { w in
                            VStack(spacing: 4) {
                                if let file = w.log.photoFile, let img = PhotoStore.load(file) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 128)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                Text(w.start.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2.bold())
                                if let r = w.log.finalRank {
                                    Text(r)
                                        .font(.caption.weight(.black).italic())
                                        .foregroundColor(Rank.color(r))
                                }
                            }
                            .onTapGesture { viewerStart = PhotoViewerStart(id: w.id) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("📸 Progress photos")
            } footer: {
                Text("Tap a photo to swipe through your transformation.")
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        let weeks = store.weekHistory
        if !weeks.isEmpty {
            let bf = weeks.compactMap { w in w.log.bodyFat.map { ChartPoint(date: w.start, value: $0) } }.sorted { $0.date < $1.date }
            if bf.count >= 2 {
                Section("Body fat %") {
                    Chart(bf) { p in
                        LineMark(x: .value("Week", p.date), y: .value("%", p.value))
                            .foregroundStyle(Attribute.vitality.color)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Week", p.date), y: .value("%", p.value))
                            .foregroundStyle(Attribute.vitality.color)
                    }
                    .chartYScale(domain: domain(bf))
                    .frame(height: 180)
                    .padding(.vertical, 6)
                }
            }
            Section("Past weeks") {
                ForEach(weeks) { w in
                    HStack(spacing: 12) {
                        Text(w.log.finalRank ?? "–")
                            .font(.system(size: 26, weight: .black, design: .rounded).italic())
                            .foregroundColor(w.log.finalRank.map { Rank.color($0) } ?? .secondary)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(weekTitle(w.start)).font(.subheadline.bold())
                            Text(statsLine(w.log)).font(.caption).foregroundColor(.secondary)
                            if !w.log.note.isEmpty {
                                Text(w.log.note).font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }

    private func addGoal() {
        store.addWeekGoal(newGoal)
        newGoal = ""
    }

    private func statsLine(_ log: WeekLog) -> String {
        var parts: [String] = []
        if let w = log.weightKg { parts.append("\(Num.text(w)) kg") }
        if let b = log.bodyFat { parts.append("\(Num.text(b))% BF") }
        if let f = log.feeling { parts.append(Feeling.emoji(f)) }
        return parts.isEmpty ? "No body stats" : parts.joined(separator: " · ")
    }

    private func domain(_ points: [ChartPoint]) -> ClosedRange<Double> {
        let values = points.map { $0.value }
        let lo = max(0, (values.min() ?? 0) - 1)
        let hi = (values.max() ?? 30) + 1
        return lo...max(hi, lo + 1)
    }
}

func weekTitle(_ start: Date) -> String {
    let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
    return "Week of \(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated)))"
}

struct WeekSheetTarget: Identifiable {
    let date: Date
    var id: Double { date.timeIntervalSince1970 }
}

enum Feeling {
    static let options = [1, 2, 3, 4, 5]
    static func emoji(_ v: Int) -> String {
        switch v {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "🔥"
        }
    }
    static func label(_ v: Int) -> String {
        switch v {
        case 1: return "Drained"
        case 2: return "Meh"
        case 3: return "OK"
        case 4: return "Good"
        default: return "On fire"
        }
    }
}

struct WeekCheckInSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let week: Date
    let onFinish: (DayScore) -> Void

    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var feeling = 4
    @State private var note = ""
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var photo: UIImage? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("⚖️ Weight")
                        Spacer()
                        TextField("kg", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kg").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("📉 Body fat")
                        Spacer()
                        TextField("%", text: $bodyFat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("%").foregroundColor(.secondary)
                    }
                } header: {
                    Text(weekTitle(store.weekStart(week)))
                }

                Section {
                    if let photo = photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .frame(maxWidth: .infinity)
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(photo == nil ? "Add this week's progress photo" : "Change photo", systemImage: "camera.fill")
                    }
                } header: {
                    Text("📸 Progress photo")
                } footer: {
                    Text("Take it in the same spot and lighting each week so the comparison is fair. Photos stay private on your phone. +10 XP")
                }

                Section("How did you feel this week?") {
                    HStack {
                        ForEach(Feeling.options, id: \.self) { v in
                            VStack(spacing: 4) {
                                Text(Feeling.emoji(v)).font(.system(size: 32))
                                Text(Feeling.label(v)).font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(feeling == v ? Theme.accent.opacity(0.3) : Color.clear))
                            .onTapGesture {
                                feeling = v
                                Haptics.tap()
                            }
                        }
                    }
                    TextField("Notes: energy, wins, what to fix next week…", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Preview") {
                    let preview = store.weekScore(week)
                    ForEach(preview.lines) { line in
                        HStack {
                            Text("\(line.emoji) \(line.title)")
                            Spacer()
                            Text("\(line.points)/\(Int(line.weight))").font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Week check-in")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let log = store.weekLog(week)
                if let w = log.weightKg { weight = Num.text(w) }
                if let b = log.bodyFat { bodyFat = Num.text(b) }
                if let f = log.feeling { feeling = f }
                note = log.note
                if let file = log.photoFile { photo = PhotoStore.load(file) }
            }
            .onChange(of: pickerItem) { item in
                guard let item = item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                            photo = UIImage(data: data)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Get rank") {
                        if let data = photoData { store.setWeekPhoto(data, week: week) }
                        let result = store.finishWeek(week, weight: Num.parse(weight), bodyFat: Num.parse(bodyFat),
                                                      feeling: feeling, note: note)
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onFinish(result) }
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

struct PhotoViewerStart: Identifiable {
    let id: String
}

struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [WeekSummary]
    @State private var selection: String

    init(photos: [WeekSummary], startID: String) {
        self.photos = photos
        _selection = State(initialValue: startID)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(photos) { w in
                    VStack(spacing: 10) {
                        if let file = w.log.photoFile, let img = PhotoStore.load(file) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                        }
                        Text(weekTitle(w.start)).font(.headline)
                        Text(caption(w.log)).font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding()
                    .tag(w.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
    }

    private func caption(_ log: WeekLog) -> String {
        var parts: [String] = []
        if let r = log.finalRank { parts.append("Rank \(r)") }
        if let w = log.weightKg { parts.append("\(Num.text(w)) kg") }
        if let b = log.bodyFat { parts.append("\(Num.text(b))% BF") }
        if let f = log.feeling { parts.append(Feeling.emoji(f)) }
        return parts.joined(separator: " · ")
    }
}
