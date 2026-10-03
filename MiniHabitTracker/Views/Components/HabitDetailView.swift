import SwiftUI
import Charts

struct HabitDetailView: View {
    let habit: Habit
    @Environment(HabitStore.self) private var habitStore
    @State private var showingEditHabit = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var currentHabit: Habit {
        habitStore.habits.first(where: { $0.id == habit.id }) ?? habit
    }
    
    var body: some View {
        ZStack{
            
            (colorScheme == .light ? Color.secondary.opacity(0.2) : Color.black)
                .ignoresSafeArea()
  
            ScrollView {
                VStack(spacing: 24) {
                    HabitPreviewCard(habit: currentHabit)
                    
                    // Stats section
                    HabitStatsSection(habit: currentHabit)
                    
                    // Recent completions
                    RecentCompletionsSection(habit: currentHabit)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle(currentHabit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditHabit = true
                    }
                }
            }
            .sheet(isPresented: $showingEditHabit) {
                EditHabitView(habit: currentHabit)
                    .environment(habitStore)
            }
        }
    }
}

struct HabitStatsSection: View {
    let habit: Habit
    @Environment(HabitStore.self) private var habitStore
    @EnvironmentObject private var store: Store
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedIndex: Int?
    @State private var selectedRange: HabitChartRange = .last7Days

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]) {
                StreakGaugeCard(
                    currentStreak: habit.streak,
                    longestStreak: longestStreak,
                    tint: habit.displayColor
                )

                CompletionRateGaugeCard(
                    completionRate: completionRate,
                    tint: habit.displayColor
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(selectedRange.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        }
                    }

                    Chart(chartData) { point in
                        BarMark(
                            x: .value("DaySlot", point.slotX),
                            y: .value("Completions", point.value),
                            width: .fixed(selectedRange == .last7Days ? 18 : (selectedRange == .pastMonth ? 10 : 14))
                        )
                        .foregroundStyle(habit.displayColor.gradient)
                        .opacity(point.value > 0 ? (selectedIndex == nil || selectedIndex == point.index ? 1.0 : 0.45) : 0.35)

                        if selectedIndex == point.index {
                            RuleMark(x: .value("Selected Day", point.slotX))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                            .annotation(position: .top) {
                                Text("\(point.value)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(habit.displayColor, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(height: 130)
                    .chartXScale(domain: 0...Double(max(1, chartData.count)))
                    .chartYScale(domain: 0...yAxisUpperBound)
                    .chartXAxis {
                        AxisMarks(values: boundaryValues) { _ in
                            AxisGridLine()
                            AxisTick()
                        }
                        AxisMarks(values: labelValues) { value in
                            if let raw = value.as(Double.self),
                               let point = chartData.first(where: { abs($0.slotX - raw) < 0.001 }) {
                                AxisValueLabel(point.label)
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
                                            let next = min(max(0, chartData.count - 1), max(0, snapped))
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
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.orange)
                        Text("Premium unlocks Past Month and Past Year analytics.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
            )
        }
        .onChange(of: store.isPremiumActive) { _, isPremium in
            if !isPremium && selectedRange != .last7Days {
                selectedRange = .last7Days
                selectedIndex = nil
            }
        }
    }

    private var availableRanges: [HabitChartRange] {
        store.isPremiumActive ? HabitChartRange.allCases : [.last7Days]
    }
    
    private var longestStreak: Int {
        habitStore.calculateLongestStreak(for: habit.id)
    }

    private var completionRate: Double {
        habitStore.calculateCompletionRate(for: habit.id, in: 30)
    }

    private var chartData: [DailyCompletionPoint] {
        let labels = periodLabels
        let values = periodValues
        return values.indices.map { index in
            DailyCompletionPoint(index: index, label: labels[index], date: Date(), value: values[index])
        }
    }

    private var periodValues: [Int] {
        switch selectedRange {
        case .last7Days:
            return habitStore.getRecentDailyTotals(for: habit.id, days: 7)
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
            let letters = calendar.shortWeekdaySymbols.map { String($0.prefix(1)) }
            return (0..<7).map { index in
                let daysAgo = 6 - index
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                let weekdayIndex = max(0, calendar.component(.weekday, from: date) - 1)
                return weekdayIndex < letters.count ? letters[weekdayIndex] : ""
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

    private var yAxisUpperBound: Int {
        let maxValue = max(periodValues.max() ?? 0, habit.usesTargetGoal ? habit.target : 1)
        return max(1, maxValue + 1)
    }

    private var yAxisMarks: [Int] {
        let top = yAxisUpperBound
        let mid = max(1, top / 2)
        return Array(Set([0, mid, top])).sorted()
    }

    private var boundaryValues: [Int] {
        let count = chartData.count
        return count > 0 ? Array(0...count) : [0]
    }

    private var labelValues: [Double] {
        switch selectedRange {
        case .last7Days, .pastMonth, .pastYear:
            return chartData.map(\.slotX)
        }
    }

    private func fiveDaySectionCounts(sectionCount: Int) -> [Int] {
        let calendar = Calendar.current
        let completions = habitStore.getCompletions(for: habit.id)
        let daysPerSection = 5
        let totalDays = sectionCount * daysPerSection
        let dayTotals: [Date: Int] = Dictionary(grouping: completions, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { $0.reduce(0) { $0 + $1.value } }

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
        let completions = habitStore.getCompletions(for: habit.id)

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
}

private enum HabitChartRange: CaseIterable {
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

struct StreakGaugeCard: View {
    let currentStreak: Int
    let longestStreak: Int
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard longestStreak > 0 else { return currentStreak > 0 ? 1.0 : 0.0 }
        return min(1.0, Double(currentStreak) / Double(longestStreak))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            Label("Streak Stats", systemImage: "flame")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(alignment: .center) {
                Text("\(currentStreak)")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text(currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Text("Longest: \(longestStreak)")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .frame(maxHeight: 140)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: currentStreak)
    }
}

struct CompletionRateGaugeCard: View {
    let completionRate: Double
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let percentage = Int((completionRate * 100).rounded())
        VStack(alignment: .center, spacing: 18) {
            Label("Completion Rate", systemImage: "gauge.with.dots.needle.50percent")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(alignment: .center) {
                Text("\(percentage)")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text("%")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text("Last 30 days")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .frame(maxHeight: 140)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: percentage)
    }
}

struct DailyCompletionPoint: Identifiable {
    var id: Int { index }
    let index: Int
    let label: String
    let date: Date
    let value: Int

    var slotX: Double {
        Double(index) + 0.5
    }
}

struct RecentCompletionsSection: View {
    let habit: Habit
    @Environment(HabitStore.self) private var habitStore
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Completions")
                .font(.title3)
                .fontWeight(.bold)
            
            let recentCompletions = habitStore.getCompletions(for: habit.id)
                .sorted { $0.date > $1.date }
                .prefix(5)
            
            if recentCompletions.isEmpty {
                Text("No completions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(Array(recentCompletions), id: \.id) { completion in
                        CompletionRow(completion: completion)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    habitStore.removeCompletion(completion)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .frame(height: CGFloat(min(recentCompletions.count, 5)) * 54)
            }
        }
    }
}

struct CompletionRow: View {
    let completion: HabitCompletion
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            
            Text(completion.date, style: .date)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if completion.value > 1 {
                Text("\(completion.value) times")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let notes = completion.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text(completion.date, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let store = HabitStore()
    let habit = Habit(
        name: "Read",
        frequency: .daily,
        usesTargetGoal: true,
        target: 2,
        unit: "Sessions",
        color: .blue
    )
    store.habits = [habit]
    store.completions = [
        HabitCompletion(habitId: habit.id, date: Date(), value: 1),
        HabitCompletion(habitId: habit.id, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, value: 2)
    ]

    return NavigationStack {
        HabitDetailView(habit: habit)
            .environment(store)
    }
}
