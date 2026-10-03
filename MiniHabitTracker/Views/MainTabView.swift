import SwiftUI
import RevenueCatUI

private enum SessionPaywallTracker {
    static var hasShown = false
}

struct MainTabView: View {
    @Environment(HabitStore.self) private var habitStore
    @EnvironmentObject var achievementManager: AchievementManager
    @EnvironmentObject var store: Store
    @State private var selectedTab = 0
    @State private var selectedDate = Date()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
                    .environment(habitStore)
                    .environmentObject(achievementManager)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            StatisticsView()
                .environment(habitStore)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(1)
            
            SettingsView()
                .environment(habitStore)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh data when app becomes active (e.g., returning from widget)
            habitStore.refreshData()
            store.loadStoredPurchases()
        }
    }
    
}

struct HomeView: View {
    @Environment(HabitStore.self) private var habitStore
    @EnvironmentObject var achievementManager: AchievementManager
    @EnvironmentObject var store: Store
    @Environment(\.requestReview) private var requestReview
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingAddHabit = false
    @State private var selectedHabit: Habit?
    @State private var draggedHabit: Habit?
    @State private var sessionStart = Date()
    @State private var hasPromptedForReview = false
    @State private var hasShownInterstitialThisSession = false
    @State private var showingPaywall = false
    private let freeHabitLimit = 2
    var body: some View {
        ZStack{
            // Background
            (colorScheme == .light ? Color.secondary.opacity(0.2) : Color.black)
                .ignoresSafeArea()
            
            ScrollView {
                if habitStore.habits.isEmpty {
                    EmptyStateView(
                        icon: "plus.circle",
                        title: "No Habits Yet",
                        subtitle: "Tap the + button to create your first habit"
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                } else {
                    if shouldUseTwoColumnGrid {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(displayedHabits) { habit in
                                HabitPreviewCard(habit: habit)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedHabit = habit
                                    }
                                    .onDrag {
                                        draggedHabit = habit
                                        return NSItemProvider(object: habit.id.uuidString as NSString)
                                    }
                                    .onDrop(
                                        of: [.text],
                                        delegate: HabitReorderDropDelegate(
                                            targetHabit: habit,
                                            draggedHabit: $draggedHabit,
                                            habitStore: habitStore
                                        )
                                    )
                                    .opacity(draggedHabit?.id == habit.id ? 0.85 : 1.0)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: displayedHabits.map(\.id))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(displayedHabits) { habit in
                                HabitPreviewCard(habit: habit)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedHabit = habit
                                    }
                                    .onDrag {
                                        draggedHabit = habit
                                        return NSItemProvider(object: habit.id.uuidString as NSString)
                                    }
                                    .onDrop(
                                        of: [.text],
                                        delegate: HabitReorderDropDelegate(
                                            targetHabit: habit,
                                            draggedHabit: $draggedHabit,
                                            habitStore: habitStore
                                        )
                                    )
                                    .opacity(draggedHabit?.id == habit.id ? 0.85 : 1.0)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: displayedHabits.map(\.id))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !store.isPremiumActive {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingPaywall = true }) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if canCreateHabit {
                            showingAddHabit = true
                        } else {
                            showingPaywall = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
                    .environment(habitStore)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(displayCloseButton: true)
            }
            .onChange(of: showingPaywall) { _, isPresented in
                if !isPresented {
                    store.loadStoredPurchases()
                }
            }
            .navigationDestination(item: $selectedHabit) { habit in
                HabitDetailView(habit: habit)
                    .environment(habitStore)
            }
            .onAppear{
                store.loadStoredPurchases()
            }
            .onChange(of: store.isPremiumActive) { _, _ in
                presentSessionPaywallIfNeeded()
            }
            .onChange(of: store.isLoading) { _, isLoading in
                if !isLoading {
                    presentSessionPaywallIfNeeded()
                }
            }
        }
    }

    private var displayedHabits: [Habit] {
        habitStore.habits.filter { $0.isActive }
    }

    private var canCreateHabit: Bool {
        store.isPremiumActive || habitStore.habits.count < freeHabitLimit
    }

    private var shouldUseTwoColumnGrid: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    }

    private func presentSessionPaywallIfNeeded() {
        guard !store.isLoading, !store.isPremiumActive, !SessionPaywallTracker.hasShown else { return }
        SessionPaywallTracker.hasShown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            showingPaywall = true
        }
    }

}

struct HabitReorderDropDelegate: DropDelegate {
    let targetHabit: Habit
    @Binding var draggedHabit: Habit?
    let habitStore: HabitStore

    func dropEntered(info: DropInfo) {
        guard let draggedHabit, draggedHabit.id != targetHabit.id else { return }

        let active = habitStore.habits.filter { $0.isActive }
        guard
            let fromIndex = active.firstIndex(where: { $0.id == draggedHabit.id }),
            let toIndex = active.firstIndex(where: { $0.id == targetHabit.id })
        else { return }

        var reorderedActive = active
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            reorderedActive.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }

        let inactive = habitStore.habits.filter { !$0.isActive }
        habitStore.habits = reorderedActive + inactive
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedHabit = nil
        habitStore.saveData()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct HabitPreviewCard: View {
    let habit: Habit
    @Environment(\.colorScheme) private var colorScheme
    @Environment(HabitStore.self) private var habitStore
    @State private var trigger: Int = 0
    @State private var waveOrigin: CGPoint = CGPoint(x: 4, y: 3)
    
    // Computed property to check if today is completed
    private var isTodayCompleted: Bool {
        let today = Date()
        return habitStore.isCompleted(for: habit.id, on: today)
    }

    private var todayTotal: Int {
        habitStore.getTotalCompletions(for: habit.id, on: Date())
    }

    private var goalTarget: Int {
        max(1, habit.target)
    }

    private var clampedTodayTotal: Int {
        min(todayTotal, goalTarget)
    }

    private var goalReachedToday: Bool {
        habit.usesTargetGoal && clampedTodayTotal >= goalTarget
    }

    private let heatmapColumnCount: Int = 9
    
    // Helper function to get today's day of week
    private var currentDayOfWeek: Int {
        let calendar = Calendar.current
        let today = Date()
        return calendar.component(.weekday, from: today) - 1
    }
    
    // Helper function to get heatmap color for a specific week and day
    private func getHeatmapColor(week: Int, day: Int) -> Color {
        return HeatmapColorUtility.heatmapColorReal(
            habitStore: habitStore,
            habitId: habit.id,
            week: week,
            day: day,
            habitColor: habit.displayColor
        )
    }
    
    // Helper function to render calendar square
    private func renderCalendarSquare(week: Int, day: Int) -> some View {
        AnimatedCalendarSquare(
            week: week,
            day: day,
            waveOrigin: waveOrigin,
            trigger: trigger,
            heatmapColor: getHeatmapColor(week: week, day: day)
        )
    }
    
    // Helper function to render today's square with overlay
    private func renderTodaySquare(week: Int, day: Int) -> some View {
        renderCalendarSquare(week: week, day: day)
            .overlay(
                Group {
                    if day == currentDayOfWeek {
                        let hasActivity = getHeatmapColor(week: week, day: day) != Color(.systemGray5)
                        
                        if !hasActivity {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color(.systemGray4), lineWidth: 1.5)
                                .frame(width: 12, height: 12)
                                .scaleEffect(1.0 + 0.1 * sin(Date().timeIntervalSince1970 * 2))
                                .opacity(0.8 + 0.2 * sin(Date().timeIntervalSince1970 * 2))
                        }
                    }
                }
            )
    }
    
    // Helper function to get today's log count string
    private var todayLogsInfoString: String {
        let logLabel = todayTotal == 1 ? "log" : "logs"
        return "\(todayTotal) \(logLabel) today"
    }
    
    var body: some View {
        HStack(spacing: 20) {
                // Left side: Calendar
                VStack(spacing: 16) {
                    // GitHub-style Heatmap (Horizontal Layout)
                    HStack(spacing: 12) {
                        // Day labels (GitHub style - vertical, localized)
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                Text(DateUtils.localizedDayAbbreviation(dayIndex: dayIndex))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(height: 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(width: 30)
                        
                        // Heatmap grid (more columns on iPad for wider cards)
                        HStack(spacing: 4) {
                            ForEach(0..<heatmapColumnCount, id: \.self) { week in
                                VStack(spacing: 4) {
                                    ForEach(0..<7, id: \.self) { day in
                                        if week < (heatmapColumnCount - 1) {
                                            // Full weeks
                                            renderCalendarSquare(week: week, day: day)
                                        } else if week == (heatmapColumnCount - 1) {
                                            // Current week - show all days up to today
                                            if day <= currentDayOfWeek {
                                                renderTodaySquare(week: week, day: day)
                                            } else {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.clear)
                                                    .frame(width: 12, height: 12)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right side: Habit Info & Actions
                VStack(spacing: 8) {
                    Spacer()
                    
                    // Habit name - aligned to the right
                    HStack {
                        Text(habit.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    // Last completion time or status - aligned to the right
                    HStack {
                        Text(todayLogsInfoString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    Spacer()
                    
                    // CHECK IN button at bottom - aligned to the right
                    HStack {
                        Spacer()
                        Button(action: {
                            let today = Date()
                            
                            // Set wave origin to today's position for animation
                            let currentDayOfWeek = Calendar.current.component(.weekday, from: today) - 1
                            waveOrigin = CGPoint(x: Double(heatmapColumnCount - 1), y: Double(currentDayOfWeek))

                            if habit.usesTargetGoal {
                                // Goal habits can continue logging even after target is reached.
                                habitStore.addCompletion(for: habit.id, value: 1)
                            } else {
                                // Binary habits toggle completion.
                                let isAlreadyCompleted = habitStore.isCompleted(for: habit.id, on: today)
                                if isAlreadyCompleted {
                                    habitStore.removeCompletion(for: habit.id, on: today)
                                } else {
                                    habitStore.addCompletion(for: habit.id, value: 1)
                                }
                            }
                            
                            // Trigger wave animation
                            trigger += 1
                            HapticManager.shared.playWaveBounce()
                        }) {
                            HStack(spacing: 8) {
                                if habit.usesTargetGoal {
                                    if goalReachedToday {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.callout)
                                            .foregroundColor(.white)
                                            .contentTransition(.symbolEffect(.replace))
                                    } else if clampedTodayTotal == 0 {
                                        Image(systemName: "plus")
                                            .font(.callout)
                                            .foregroundColor(.white)
                                            .contentTransition(.symbolEffect(.replace))
                                    } else {
                                        Text("\(clampedTodayTotal)/\(goalTarget)")
                                            .font(.caption.bold())
                                            .monospacedDigit()
                                            .foregroundColor(.white)
                                            .contentTransition(.numericText())
                                    }
                                } else {
                                    Image(systemName: isTodayCompleted ? "checkmark.circle.fill" : "plus")
                                        .font(.callout)
                                        .foregroundColor(.white)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: clampedTodayTotal)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isTodayCompleted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill((isTodayCompleted || goalReachedToday) ? habit.displayColor : Color(.systemGray4))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: 140, alignment: .trailing)
        }
        .frame(height: 130)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
        )
        .frame(maxWidth: .infinity)
    }
}

struct HomeHeaderView: View {
    @Environment(HabitStore.self) private var habitStore
    private var todayStats: HabitStore.TodayProgressStats {
        habitStore.todayProgressStats()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Today's date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todayString)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(dayString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Progress ring
                VStack(spacing: 4) {
                    ProgressRing(
                        progress: todayStats.completionProgress,
                        size: 60,
                        lineWidth: 6,
                        color: .blue
                    )
                    
                    Text("\(todayStats.completedCount)/\(todayStats.activeHabitsCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            ProgressView(value: todayStats.completionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
}

struct HomeHabitCard: View {
    let habit: Habit
    let onTap: () -> Void
    
    @Environment(HabitStore.self) private var habitStore
    @State private var showingCompletionSheet = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Left side: Weekly calendar grid
                VStack(spacing: 4) {
                    // Day labels vertically
                    VStack(spacing: 2) {
                        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                            Text(day)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: 25, alignment: .leading)
                        }
                    }
                    
                    // Completion grid to the right of day labels
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { dayOffset in
                            let date = Calendar.current.date(byAdding: .day, value: dayOffset - 6, to: Date()) ?? Date()
                            let isCompleted = habitStore.isCompleted(for: habit.id, on: date)
                            let isToday = Calendar.current.isDateInToday(date)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isCompleted ? habit.displayColor : Color(.systemGray5))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(isToday ? habit.displayColor : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
                
                // Right side: Habit details
                VStack(alignment: .leading, spacing: 8) {
                    // Habit name
                    Text(habit.name)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    
                    // Current time
                    Text(currentTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Quick completion button
                    Button(action: {
                        showingCompletionSheet = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "plus")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                    .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingCompletionSheet) {
            HabitCompletionSheet(habit: habit)
                .environment(habitStore)
        }
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
}

// Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
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
