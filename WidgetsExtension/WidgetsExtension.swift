import WidgetKit
import SwiftUI
import AppIntents

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: EnhancedConfigurationAppIntent(),
            habit: sampleHabit,
            todayTotal: 2,
            todayProgress: 0.66,
            dailyTotals: sampleDailyTotals,
            rippleProgress: 0.65,
            rippleHabitId: sampleHabit.id.uuidString
        )
    }

    func snapshot(for configuration: EnhancedConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        if context.isPreview {
            return SimpleEntry(
                date: Date(),
                configuration: configuration,
                habit: sampleHabit,
                todayTotal: 2,
                todayProgress: 0.66,
                dailyTotals: sampleDailyTotals,
                rippleProgress: 0.65,
                rippleHabitId: sampleHabit.id.uuidString
            )
        }
        return makeEntry(for: configuration)
    }

    func timeline(for configuration: EnhancedConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let now = Date()
        let first = makeEntry(for: configuration, at: now)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now

        guard first.rippleProgress > 0.01 else {
            return Timeline(entries: [first], policy: .after(nextUpdate))
        }

        let settleDate = now.addingTimeInterval(2.0)
        let settled = makeEntry(for: configuration, at: settleDate, forcedRippleProgress: 0)
        return Timeline(entries: [first, settled], policy: .after(nextUpdate))
    }

    private func makeEntry(
        for configuration: EnhancedConfigurationAppIntent,
        at now: Date = Date(),
        forcedRippleProgress: Double? = nil
    ) -> SimpleEntry {
        let allHabits = SharedDataManager.shared.loadHabits()
        let fallbackHabitID = allHabits.first?.id.uuidString
        let configuredID = configuration.selectedHabit?.id
        let selectedHabitID: String?
        if let configuredID,
           UUID(uuidString: configuredID) != nil,
           allHabits.contains(where: { $0.id.uuidString == configuredID }) {
            selectedHabitID = configuredID
        } else {
            selectedHabitID = fallbackHabitID
        }
        let habit = selectedHabitID.flatMap(loadHabit)
        let todayTotal = selectedHabitID.map(todayTotal(for:)) ?? 0
        let progress = normalizedProgress(for: habit, todayTotal: todayTotal)
        let dailyTotals = selectedHabitID.map { loadDailyTotals(for: $0, days: 98) } ?? [:]

        let rippleState = SharedDataManager.shared.widgetRippleState()
        let rippleProgress: Double = forcedRippleProgress ?? {
            guard let rippleState else { return 0 }
            let elapsed = now.timeIntervalSince(rippleState.date)
            guard elapsed >= 0, elapsed <= 2.2 else { return 0 }
            return max(0, 1 - (elapsed / 2.2))
        }()

        return SimpleEntry(
            date: Date(),
            configuration: configuration,
            habit: habit,
            todayTotal: todayTotal,
            todayProgress: progress,
            dailyTotals: dailyTotals,
            rippleProgress: rippleProgress,
            rippleHabitId: rippleState?.habitId
        )
    }

    private func loadHabit(for habitId: String) -> Habit? {
        guard !habitId.isEmpty else { return nil }
        return SharedDataManager.shared.loadHabits().first { $0.id.uuidString == habitId }
    }

    private func todayTotal(for habitId: String) -> Int {
        guard !habitId.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = Date()

        return SharedDataManager.shared
            .loadCompletions()
            .filter { $0.habitId.uuidString == habitId && calendar.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + max(0, $1.value) }
    }

    private func loadDailyTotals(for habitId: String, days: Int) -> [Date: Int] {
        guard !habitId.isEmpty else { return [:] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let earliest = calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: start) ?? start

        var totals: [Date: Int] = [:]
        for completion in SharedDataManager.shared.loadCompletions() where completion.habitId.uuidString == habitId {
            let day = calendar.startOfDay(for: completion.date)
            guard day >= earliest else { continue }
            totals[day, default: 0] += max(0, completion.value)
        }
        return totals
    }

    private func normalizedProgress(for habit: Habit?, todayTotal: Int) -> Double {
        guard let habit else { return 0 }
        if habit.usesTargetGoal {
            return min(1.0, Double(todayTotal) / Double(max(1, habit.target)))
        }
        return todayTotal > 0 ? 1.0 : 0.0
    }

    private var sampleHabit: Habit {
        Habit(
            id: UUID(),
            name: "Hydration",
            frequency: .daily,
            usesTargetGoal: true,
            target: 3,
            unit: "Count",
            color: .blue,
            customColorHex: nil,
            isActive: true,
            createdAt: Date(),
            streak: 0,
            totalCompletions: 0,
            lastCompletedDate: nil
        )
    }

    private var sampleDailyTotals: [Date: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var values: [Date: Int] = [:]
        for offset in 0..<98 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let seed = (offset * 9301 + 49297) % 233280
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            let threshold = isWeekend ? 4 : 5
            let completed = (seed % 6) < threshold
            values[date] = completed ? (1 + (seed % 3)) : 0
        }
        return values
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: EnhancedConfigurationAppIntent
    let habit: Habit?
    let todayTotal: Int
    let todayProgress: Double
    let dailyTotals: [Date: Int]
    let rippleProgress: Double
    let rippleHabitId: String?
}

struct WidgetEmptyStateView: View {
    let hasHabits: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: hasHabits ? "plus.circle.fill" : "square.stack.3d.up.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(hasHabits ? "Hold to Configure" : "No Habits Yet")
                .font(.headline)
            Text(hasHabits ? "Pick a habit" : "Create one in the app")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HabitTilesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SimpleEntry

    var body: some View {
        if let habit = entry.habit {
            if family == .systemMedium {
                mediumCardLayout(habit: habit)
                    .padding(.vertical, 8)
            } else {
                smallLayout(habit: habit)
                    .padding(.vertical, 6)
            }
        } else {
            WidgetEmptyStateView(hasHabits: !SharedDataManager.shared.loadHabits().isEmpty)
        }
    }

    private func smallLayout(habit: Habit) -> some View {
        VStack(spacing: 8) {
            heatmapGrid(habit: habit, columns: 9, tileSize: 12, tileSpacing: 2, dayLabelWidth: 16, dayLabelSize: 10, abbreviatedDays: false)

            Button(intent: logIntent(habit)) {
                Text("Log")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(habit.displayColor)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediumCardLayout(habit: Habit) -> some View {
        HStack(spacing: 8) {
            heatmapGrid(habit: habit, columns: 9, tileSize: 14, tileSpacing: 2.5, dayLabelWidth: 28, dayLabelSize: 10, abbreviatedDays: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                Spacer(minLength: 0)

                Text(habit.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.trailing)

                Text(todayLogsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(intent: logIntent(habit)) {
                    HStack(spacing: 6) {
                        if habit.usesTargetGoal {
                            if entry.todayTotal >= max(1, habit.target) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption.weight(.bold))
                            } else {
                                Text("\(entry.todayTotal)/\(max(1, habit.target))")
                                    .font(.caption.weight(.bold))
                                    .monospacedDigit()
                            }
                        } else {
                            Image(systemName: entry.todayTotal > 0 ? "checkmark.circle.fill" : "plus")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            (entry.todayProgress >= 1 || (!habit.usesTargetGoal && entry.todayTotal > 0))
                            ? habit.displayColor
                            : Color(.systemGray4)
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(width: 98)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func heatmapGrid(habit: Habit, columns: Int, tileSize: CGFloat, tileSpacing: CGFloat, dayLabelWidth: CGFloat, dayLabelSize: CGFloat, abbreviatedDays: Bool) -> some View {
        let todayWeekday = Calendar.current.component(.weekday, from: Date()) - 1
        let todayWeek = columns - 1
        return HStack(spacing: 5) {
            VStack(alignment: .leading, spacing: tileSpacing) {
                ForEach(0..<7, id: \.self) { idx in
                    Text(dayLabel(for: idx, abbreviated: abbreviatedDays))
                        .font(.system(size: dayLabelSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(height: tileSize)
                }
            }
            .frame(width: dayLabelWidth, alignment: .leading)

            HStack(spacing: tileSpacing) {
                ForEach(0..<columns, id: \.self) { week in
                    VStack(spacing: tileSpacing) {
                        ForEach(0..<7, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tileColor(habit: habit, week: week, day: day, columns: columns))
                                .overlay(
                                    Group {
                                        if week == todayWeek, day == todayWeekday {
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(habit.displayColor, lineWidth: 1.8)
                                        }
                                    }
                                )
                                .overlay(
                                    Group {
                                        if entry.rippleProgress > 0.01,
                                           entry.rippleHabitId == habit.id.uuidString,
                                           week == todayWeek,
                                           day == todayWeekday {
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(habit.displayColor.opacity(0.95), lineWidth: 2.2)
                                        }
                                    }
                                )
                                .frame(width: tileSize, height: tileSize)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 2.0), value: entry.rippleProgress)
    }

    private func logIntent(_ habit: Habit) -> LogHabitIntent {
        LogHabitIntent(habit: HabitEntity(id: habit.id.uuidString, name: habit.name, color: habit.color.rawValue))
    }

    private var todayLogsText: String {
        let label = entry.todayTotal == 1 ? "log" : "logs"
        return "\(entry.todayTotal) \(label) today"
    }

    private func dayLabel(for index: Int, abbreviated: Bool) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard index < symbols.count else { return "" }
        return abbreviated ? symbols[index] : String(symbols[index].prefix(1))
    }

    private func tileColor(habit: Habit, week: Int, day: Int, columns: Int) -> Color {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: startOfToday) - 1
        let startOfWeek = calendar.date(byAdding: .day, value: -weekday, to: startOfToday) ?? startOfToday

        let weeksFromCurrent = (columns - 1) - week
        let base = calendar.date(byAdding: .day, value: -(weeksFromCurrent * 7), to: startOfWeek) ?? startOfWeek
        let date = calendar.date(byAdding: .day, value: day, to: base) ?? base

        if date > startOfToday {
            return Color.clear
        }

        let total = entry.dailyTotals[calendar.startOfDay(for: date)] ?? 0
        let intensity: Double
        if habit.usesTargetGoal {
            intensity = min(1.0, Double(total) / Double(max(1, habit.target)))
        } else {
            intensity = total > 0 ? 1.0 : 0.0
        }

        let baseColor: Color
        if intensity <= 0 {
            baseColor = Color.secondary.opacity(0.22)
        } else {
            baseColor = habit.displayColor.opacity(0.28 + (0.72 * intensity))
        }

        guard
            entry.rippleProgress > 0,
            entry.rippleHabitId == habit.id.uuidString
        else { return baseColor }

        let todayWeekday = calendar.component(.weekday, from: startOfToday) - 1
        let originWeek = columns - 1
        let originDay = todayWeekday
        let distance = sqrt(pow(Double(week - originWeek), 2) + pow(Double(day - originDay), 2))
        let wavePosition = 0.35 + (2.4 * (1 - entry.rippleProgress))
        let bandDistance = abs(distance - wavePosition)
        let bandStrength = max(0, 1 - (bandDistance / 1.9)) * entry.rippleProgress

        guard bandStrength > 0 else { return baseColor }
        return habit.displayColor.opacity(min(1.0, 0.45 + (bandStrength * 0.95)))
    }
}

struct HabitLogWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        if let habit = entry.habit {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(habit.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(trailingValue(habit: habit))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.todayProgress >= 1 ? habit.displayColor : .secondary)
                        .contentTransition(.numericText())
                }

                progressBar(habit: habit)

                HStack {
                    Text(statusText(habit: habit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button(intent: LogHabitIntent(habit: HabitEntity(id: habit.id.uuidString, name: habit.name, color: habit.color.rawValue))) {
                        if habit.usesTargetGoal, entry.todayTotal >= max(1, habit.target) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                        } else {
                            Label("Log", systemImage: "plus.circle.fill")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(habit.displayColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
        } else {
            WidgetEmptyStateView(hasHabits: !SharedDataManager.shared.loadHabits().isEmpty)
        }
    }

    private func progressBar(habit: Habit) -> some View {
        GeometryReader { geo in
            let width = max(0, geo.size.width)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(habit.displayColor)
                    .frame(width: width * entry.todayProgress)
            }
        }
        .frame(height: 12)
    }

    private func trailingValue(habit: Habit) -> String {
        if habit.usesTargetGoal {
            return "\(entry.todayTotal)/\(max(1, habit.target))"
        }
        return entry.todayTotal > 0 ? "Done" : "Pending"
    }

    private func statusText(habit: Habit) -> String {
        if habit.usesTargetGoal {
            return entry.todayProgress >= 1 ? "Goal reached" : "Keep going"
        }
        return entry.todayTotal > 0 ? "Completed today" : "Not completed today"
    }
}

struct HabitTilesWidget: Widget {
    let kind: String = "HabitTilesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: EnhancedConfigurationAppIntent.self, provider: Provider()) { entry in
            HabitTilesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit Tiles")
        .description("Heatmap tiles with quick logging for one habit")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HabitLogWidget: Widget {
    let kind: String = "HabitLogWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: EnhancedConfigurationAppIntent.self, provider: Provider()) { entry in
            HabitLogWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit Logger")
        .description("Track and log progress for one habit")
        .supportedFamilies([.systemMedium])
    }
}

private extension SimpleEntry {
    static var previewSample: SimpleEntry {
        let habit = Habit(
            id: UUID(),
            name: "Hydration",
            frequency: .daily,
            usesTargetGoal: true,
            target: 3,
            unit: "Count",
            color: .blue,
            customColorHex: nil,
            isActive: true,
            createdAt: Date(),
            streak: 5,
            totalCompletions: 42,
            lastCompletedDate: Date()
        )

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var totals: [Date: Int] = [:]
        for offset in 0..<98 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let seed = (offset * 9301 + 49297) % 233280
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            let threshold = isWeekend ? 4 : 5
            let completed = (seed % 6) < threshold
            totals[date] = completed ? (1 + (seed % 3)) : 0
        }

        return SimpleEntry(
            date: Date(),
            configuration: EnhancedConfigurationAppIntent(),
            habit: habit,
            todayTotal: 2,
            todayProgress: 0.66,
            dailyTotals: totals,
            rippleProgress: 0.9,
            rippleHabitId: habit.id.uuidString
        )
    }
}
