import SwiftUI
import Charts

struct StudyDraft: Identifiable {
    let id = UUID()
    var minutes: Int
}

struct StudyView: View {
    @EnvironmentObject var store: Store
    @AppStorage("studyTimerStart") private var timerStart: Double = 0
    @State private var logDraft: StudyDraft? = nil

    var body: some View {
        NavigationStack {
            List {
                Section { header }

                Section("Focus timer") {
                    if timerStart > 0 {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let elapsed = max(0, Int(context.date.timeIntervalSince1970 - timerStart))
                            HStack {
                                Spacer()
                                Text(clock(elapsed))
                                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                                    .foregroundColor(Attribute.intellect.color)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        Button {
                            let minutes = max(1, Int((Date().timeIntervalSince1970 - timerStart) / 60))
                            timerStart = 0
                            logDraft = StudyDraft(minutes: minutes)
                        } label: {
                            Label("Finish & log session", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                        }
                        Button("Cancel timer", role: .destructive) { timerStart = 0 }
                    } else {
                        Button {
                            timerStart = Date().timeIntervalSince1970
                        } label: {
                            Label("Start focus session", systemImage: "timer")
                                .font(.headline)
                        }
                        Text("The timer keeps running even if you close the app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button {
                        logDraft = StudyDraft(minutes: 30)
                    } label: {
                        Label("Log a session manually", systemImage: "square.and.pencil")
                    }
                }

                Section("Last 7 days") {
                    weekChart
                }

                if !store.minutesBySubject().isEmpty {
                    Section("By subject") {
                        ForEach(store.minutesBySubject()) { item in
                            HStack {
                                Text(item.subject.isEmpty ? "General" : item.subject)
                                Spacer()
                                Text(hours(item.minutes))
                                    .foregroundColor(Attribute.intellect.color)
                                    .bold()
                            }
                        }
                    }
                }

                Section("Sessions") {
                    if store.data.studySessions.isEmpty {
                        Text("No sessions yet. Start the focus timer!").foregroundColor(.secondary)
                    }
                    ForEach(store.data.studySessions) { s in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(s.subject.isEmpty ? "General" : s.subject).font(.headline)
                                Spacer()
                                Text("\(s.minutes) min").bold().foregroundColor(Attribute.intellect.color)
                            }
                            Text(s.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !s.note.isEmpty {
                                Text(s.note).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.data.studySessions[$0].id }
                        for id in ids { store.deleteStudy(id) }
                    }
                }
            }
            .gameListStyle()
            .navigationTitle("Study")
            .sheet(item: $logDraft) { draft in
                StudyLogSheet(minutes: draft.minutes)
                    .environmentObject(store)
            }
        }
    }

    private var header: some View {
        let mins = store.studyMinutes(on: Date())
        let target = store.profile.studyMinutesTarget
        let info = Leveling.attributeInfo(store.xp(.intellect))
        return HStack(spacing: 16) {
            ZStack {
                ProgressRing(value: Double(mins) / Double(max(1, target)), color: Attribute.intellect.color, lineWidth: 10)
                VStack(spacing: 0) {
                    Text("\(mins)").font(.headline)
                    Text("/ \(target)m").font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 6) {
                Text("🧠 Intellect Lv \(info.level)").font(.headline)
                ProgressBar(value: info.fraction, color: Attribute.intellect.color, height: 8)
                Text("Total: \(hours(store.totalStudyMinutes)). You get 1 XP per 2 minutes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var weekChart: some View {
        let points = store.studyLastDays(7)
        let target = Double(store.profile.studyMinutesTarget)
        return Chart {
            ForEach(points) { p in
                BarMark(x: .value("Day", p.date, unit: .day), y: .value("Minutes", p.value))
                    .foregroundStyle(p.value >= target ? Attribute.intellect.color : Attribute.intellect.color.opacity(0.5))
                    .cornerRadius(6)
            }
            RuleMark(y: .value("Target", target))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }

    private func clock(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func hours(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct StudyLogSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var minutes: Int
    @State private var date = Date()
    @State private var note = ""

    init(minutes: Int) {
        _minutes = State(initialValue: minutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Subject") {
                    TextField("e.g. Math, Biology, Spanish", text: $subject)
                    if !store.data.subjects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.data.subjects, id: \.self) { s in
                                    Button(s) { subject = s }
                                        .buttonStyle(.bordered)
                                        .tint(subject == s ? Attribute.intellect.color : .gray)
                                }
                            }
                        }
                    }
                }
                Section("Session") {
                    Stepper("Duration: \(minutes) min", value: $minutes, in: 1...600, step: 5)
                    DatePicker("When", selection: $date)
                    TextField("Note (optional)", text: $note)
                }
                Section {
                    Text("This session is worth +\(max(5, minutes / 2)) XP 🧠")
                        .foregroundColor(Attribute.intellect.color)
                }
            }
            .navigationTitle("Log study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addStudy(StudySession(
                            date: date,
                            subject: subject.trimmingCharacters(in: .whitespaces),
                            minutes: minutes,
                            note: note
                        ))
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
