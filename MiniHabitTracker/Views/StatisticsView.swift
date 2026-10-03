import SwiftUI
import Charts

struct StatisticsView: View {
    @Environment(HabitStore.self) private var habitStore
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: Store

    var body: some View {
        NavigationStack {
            ZStack{
                // Background
                (colorScheme == .light ? Color.secondary.opacity(0.2) : Color.black)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        StatisticsHeroCard()
                        WeeklySnapshotCard()
                        AchievementsSectionCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .navigationTitle("Statistics")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

private struct StatisticsHeroCard: View {
    @Environment(HabitStore.self) private var habitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                StatisticsCard(
                    title: "Completion Rate",
                    value: "\(Int((weekRate * 100).rounded()))%",
                    subtitle: "Last 7 days",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    progress: weekRate
                )
                
                StatisticsCard(
                    title: "Total Logs",
                    value: "\(habitStore.completions.count)",
                    subtitle: "All time",
                    icon: "number.circle.fill",
                    color: .blue
                )
            }
        }
    }

    private var weekRate: Double {
        let calendar = Calendar.current
        let activeHabits = habitStore.habits.filter { $0.isActive }
        guard !activeHabits.isEmpty else { return 0 }

        let last7Dates: [Date] = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: Date())
        }

        let completions = activeHabits.reduce(0) { partial, habit in
            partial + last7Dates.filter { habitStore.isCompleted(for: habit.id, on: $0) }.count
        }
        let totalPossible = activeHabits.count * 7
        return totalPossible > 0 ? Double(completions) / Double(totalPossible) : 0
    }
}

private struct WeeklySnapshotCard: View {
    @Environment(HabitStore.self) private var habitStore
    @EnvironmentObject private var store: Store
    @State private var selectedIndex: Int?
    @State private var selectedRange: StatsRange = .last7Days
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(selectedRange.title)
                        .font(.headline)
                    Spacer()
                    Menu {
                        ForEach(availableRanges, id: \.self) { range in
                            Button(range.title) {
                                selectedRange = range
                                selectedIndex = nil
                            }
                        }
                    } label: {
                        Label("Range", systemImage: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                }

                Chart(chartPoints) { point in
                    BarMark(
                        x: .value("Bucket", point.slotX),
                        y: .value("Completions", point.value),
                        width: .fixed(selectedRange == .last7Days ? 18 : (selectedRange == .pastMonth ? 7 : 14))
                    )
                    .foregroundStyle(.blue.gradient)
                    .opacity(point.value > 0 ? (selectedIndex == nil || selectedIndex == point.index ? 1.0 : 0.45) : 0.35)

                    if selectedIndex == point.index {
                        RuleMark(x: .value("Selected Bucket", point.slotX))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .annotation(position: .top) {
                                Text("\(point.value)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .frame(height: 130)
                .chartXScale(domain: 0...Double(max(1, chartPoints.count)))
                .chartYScale(domain: 0...yAxisUpperBound)
                .chartXAxis {
                    AxisMarks(values: boundaryValues) { _ in
                        AxisGridLine()
                        AxisTick()
                    }
                    AxisMarks(values: labelValues) { value in
                        if let raw = value.as(Double.self),
                           let point = chartPoints.first(where: { abs($0.slotX - raw) < 0.001 }) {
                            AxisValueLabel(
                                point.label,
                                anchor: value.index == 0
                                ? .topLeading
                                : value.index == value.count - 1 ? .topTrailing : .top
                            )
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: yAxisMarks)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let origin = geometry[plotFrame].origin
                                        let x = value.location.x - origin.x
                                        guard
                                            x >= 0,
                                            x <= proxy.plotSize.width,
                                            let rawX: Double = proxy.value(atX: x)
                                        else { return }
                                        let snapped = Int(floor(rawX))
                                        let next = min(max(0, chartPoints.count - 1), max(0, snapped))
                                        if selectedIndex != next {
                                            selectedIndex = next
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedIndex = nil
                                    }
                            )
                    }
                }
            }
            if !store.isPremiumActive {
                premiumUpsell
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .onChange(of: store.isPremiumActive) { _, isPremium in
            if !isPremium && selectedRange != .last7Days {
                selectedRange = .last7Days
                selectedIndex = nil
            }
        }
    }

    private var availableRanges: [StatsRange] {
        store.isPremiumActive ? StatsRange.allCases : [.last7Days]
    }

    private var premiumUpsell: some View {
        HStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .foregroundStyle(.orange)
            Text("Premium unlocks Past Month and Past Year analytics.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var chartPoints: [WeeklyPoint] {
        let counts = periodCounts
        let labels = periodLabels
        return counts.indices.map { index in
            WeeklyPoint(index: index, label: labels[index], value: counts[index])
        }
    }

    private var periodCounts: [Int] {
        switch selectedRange {
        case .last7Days:
            return dailyCounts(days: 7)
        case .pastMonth:
            return fiveDaySectionCounts(sectionCount: 7)
        case .pastYear:
            return monthlyCounts(months: 12)
        }
    }

    private var periodLabels: [String] {
        let calendar = Calendar.current
        switch selectedRange {
        case .last7Days:
            return (0..<7).map { offset in
                let date = calendar.date(byAdding: .day, value: -(6 - offset), to: Date()) ?? Date()
                return date.formatted(.dateTime.weekday(.narrow))
            }
        case .pastMonth:
            return (0..<7).map { section in
                let daysPerSection = 5
                let totalDays = 7 * daysPerSection
                let endOffset = (totalDays - 1) - (section * daysPerSection)

                let endDate = calendar.date(byAdding: .day, value: -endOffset, to: Date()) ?? Date()
                return endDate.formatted(.dateTime.day())
            }
        case .pastYear:
            return (0..<12).map { offset in
                let start = calendar.date(byAdding: .month, value: -(11 - offset), to: Date()) ?? Date()
                return start.formatted(.dateTime.month(.narrow))
            }
        }
    }

    private func dailyCounts(days: Int) -> [Int] {
        let calendar = Calendar.current
        let dayTotals: [Date: Int] = Dictionary(
            grouping: habitStore.completions,
            by: { calendar.startOfDay(for: $0.date) }
        ).mapValues { completions in
            completions.reduce(0) { $0 + $1.value }
        }

        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: -((days - 1) - offset), to: Date()) ?? Date()
            return dayTotals[calendar.startOfDay(for: date)] ?? 0
        }
    }

    private func fiveDaySectionCounts(sectionCount: Int) -> [Int] {
        let calendar = Calendar.current
        let daysPerSection = 5
        let totalDays = sectionCount * daysPerSection
        let dayTotals: [Date: Int] = Dictionary(
            grouping: habitStore.completions,
            by: { calendar.startOfDay(for: $0.date) }
        ).mapValues { completions in
            completions.reduce(0) { $0 + $1.value }
        }

        return (0..<sectionCount).map { section in
            (0..<daysPerSection).reduce(0) { partial, dayInSection in
                let dayOffset = (totalDays - 1) - (section * daysPerSection + dayInSection)
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
                return partial + (dayTotals[calendar.startOfDay(for: date)] ?? 0)
            }
        }
    }

    private func monthlyCounts(months: Int) -> [Int] {
        let calendar = Calendar.current
        let completions = habitStore.completions

        return (0..<months).map { offset in
            let monthOffset = (months - 1) - offset
            let anchor = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) ?? Date()
            let date = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
            guard let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }

            return completions.reduce(0) { partial, completion in
                guard completion.date >= interval.start && completion.date < interval.end else { return partial }
                return partial + completion.value
            }
        }
    }

    private var boundaryValues: [Int] {
        let count = chartPoints.count
        guard count > 0 else { return [0] }
        return Array(0...count)
    }

    private var labelValues: [Double] {
        let count = chartPoints.count
        guard count > 0 else { return [] }
        switch selectedRange {
        case .last7Days:
            return chartPoints.map(\.slotX)
        case .pastMonth:
            return chartPoints.map(\.slotX)
        case .pastYear:
            return chartPoints.map(\.slotX)
        }
    }

    private var yAxisUpperBound: Int {
        max(1, (periodCounts.max() ?? 0) + 1)
    }

    private var yAxisMarks: [Int] {
        let top = yAxisUpperBound
        let mid = max(1, top / 2)
        return Array(Set([0, mid, top])).sorted()
    }
}

private enum StatsRange: CaseIterable {
    case last7Days
    case pastMonth
    case pastYear

    var title: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .pastMonth: return "Past Month"
        case .pastYear: return "Past Year"
        }
    }
}

private struct AchievementsSectionCard: View {
    @Environment(HabitStore.self) private var habitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                Text("\(unlocked.count)/\(achievements.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(achievements, id: \.title) { achievement in
                AchievementCard(
                    title: achievement.title,
                    description: achievement.description,
                    icon: achievement.icon,
                    color: achievement.color,
                    isUnlocked: achievement.isUnlocked
                )
            }
        }
    }

    private var achievements: [Achievement] {
        let totalHabits = habitStore.habits.count
        let activeHabits = habitStore.habits.filter { $0.isActive }.count
        let totalCompletions = habitStore.completions.count
        let maxStreak = habitStore.habits.map(\.streak).max() ?? 0
        let goalHabits = habitStore.habits.filter(\.usesTargetGoal).count
        let reminderHabits = habitStore.habits.filter { $0.reminderTime != nil }.count
        let customColorHabits = habitStore.habits.filter { $0.color == .custom }.count
        let weeklyHabits = habitStore.habits.filter { $0.frequency == .weekly }.count
        let monthlyHabits = habitStore.habits.filter { $0.frequency == .monthly }.count
        let distinctActiveDays = Set(habitStore.completions.map { Calendar.current.startOfDay(for: $0.date) }).count

        return [
            Achievement(title: "First Habit", description: "Create your first habit", icon: "plus.circle.fill", color: .blue, isUnlocked: totalHabits >= 1),
            Achievement(title: "Starter Pack", description: "Create 3 habits", icon: "square.stack.3d.up.fill", color: .blue, isUnlocked: totalHabits >= 3),
            Achievement(title: "Habit Master", description: "Create 5 habits", icon: "list.bullet.circle.fill", color: .green, isUnlocked: totalHabits >= 5),
            Achievement(title: "Habit Architect", description: "Create 10 habits", icon: "building.columns.fill", color: .green, isUnlocked: totalHabits >= 10),
            Achievement(title: "Habit Empire", description: "Create 20 habits", icon: "crown.fill", color: .indigo, isUnlocked: totalHabits >= 20),

            Achievement(title: "First Check-in", description: "Log your first completion", icon: "checkmark.circle.fill", color: .teal, isUnlocked: totalCompletions >= 1),
            Achievement(title: "Momentum", description: "Log 25 completions", icon: "bolt.fill", color: .teal, isUnlocked: totalCompletions >= 25),
            Achievement(title: "Dedication", description: "Log 100 completions", icon: "checkmark.circle.fill", color: .purple, isUnlocked: totalCompletions >= 100),
            Achievement(title: "Deep Focus", description: "Log 250 completions", icon: "brain.head.profile", color: .purple, isUnlocked: totalCompletions >= 250),
            Achievement(title: "Unstoppable", description: "Log 500 completions", icon: "infinity.circle.fill", color: .pink, isUnlocked: totalCompletions >= 500),

            Achievement(title: "First Flame", description: "Reach a 3-day streak", icon: "flame.fill", color: .orange, isUnlocked: maxStreak >= 3),
            Achievement(title: "Consistency", description: "Reach a 7-day streak", icon: "flame.fill", color: .orange, isUnlocked: maxStreak >= 7),
            Achievement(title: "Two-Week Fire", description: "Reach a 14-day streak", icon: "flame.circle.fill", color: .orange, isUnlocked: maxStreak >= 14),
            Achievement(title: "Streak Legend", description: "Reach a 30-day streak", icon: "trophy.fill", color: .yellow, isUnlocked: maxStreak >= 30),
            Achievement(title: "Iron Will", description: "Reach a 60-day streak", icon: "medal.fill", color: .yellow, isUnlocked: maxStreak >= 60),

            Achievement(title: "Active Lifestyle", description: "Have 3 active habits", icon: "figure.run", color: .red, isUnlocked: activeHabits >= 3),
            Achievement(title: "Always On", description: "Have 5 active habits", icon: "bolt.heart.fill", color: .red, isUnlocked: activeHabits >= 5),
            Achievement(title: "System Builder", description: "Have 10 active habits", icon: "gearshape.2.fill", color: .red, isUnlocked: activeHabits >= 10),

            Achievement(title: "Goal Setter", description: "Create 1 goal-based habit", icon: "target", color: .mint, isUnlocked: goalHabits >= 1),
            Achievement(title: "Goal Hunter", description: "Create 3 goal-based habits", icon: "scope", color: .mint, isUnlocked: goalHabits >= 3),
            Achievement(title: "Goal Strategist", description: "Create 5 goal-based habits", icon: "target", color: .mint, isUnlocked: goalHabits >= 5),

            Achievement(title: "On Schedule", description: "Set a reminder for 1 habit", icon: "bell.fill", color: .cyan, isUnlocked: reminderHabits >= 1),
            Achievement(title: "Reminder Crew", description: "Set reminders for 3 habits", icon: "bell.badge.fill", color: .cyan, isUnlocked: reminderHabits >= 3),
            Achievement(title: "Reminder Pro", description: "Set reminders for 5 habits", icon: "bell.and.waves.left.and.right.fill", color: .cyan, isUnlocked: reminderHabits >= 5),

            Achievement(title: "Color Explorer", description: "Use a custom color", icon: "paintpalette.fill", color: .pink, isUnlocked: customColorHabits >= 1),
            Achievement(title: "Color Collector", description: "Use custom colors on 3 habits", icon: "eyedropper.full", color: .pink, isUnlocked: customColorHabits >= 3),

            Achievement(title: "Weekly Planner", description: "Create a weekly habit", icon: "calendar", color: .indigo, isUnlocked: weeklyHabits >= 1),
            Achievement(title: "Monthly Planner", description: "Create a monthly habit", icon: "calendar.badge.clock", color: .indigo, isUnlocked: monthlyHabits >= 1),

            Achievement(title: "Daily Return", description: "Log activity on 7 different days", icon: "sun.max.fill", color: .yellow, isUnlocked: distinctActiveDays >= 7),
            Achievement(title: "Habit Resident", description: "Log activity on 30 different days", icon: "house.fill", color: .brown, isUnlocked: distinctActiveDays >= 30)
        ]
    }

    private var unlocked: [Achievement] {
        achievements.filter(\.isUnlocked)
    }
}

private struct EmptyStateRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

struct Achievement {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
}

private struct WeeklyPoint: Identifiable {
    let index: Int
    let label: String
    let value: Int

    var id: Int { index }
    var slotX: Double { Double(index) + 0.5 }
}

#Preview{
    StatisticsView()
        .environment(HabitStore())
}
