import Foundation
import SwiftUI
import Observation
import WidgetKit

// MARK: - Habit Store
@MainActor
@Observable
class HabitStore {
    var habits: [Habit] = []
    var completions: [HabitCompletion] = []
    var selectedDate: Date = Date()

    struct TodayProgressStats {
        let activeHabitsCount: Int
        let completedCount: Int
        let completionProgress: Double
    }
    
    private let habitsKey = "SavedHabits"
    private let completionsKey = "SavedCompletions"
    private var pendingSaveTask: Task<Void, Never>?
    private var pendingWidgetReloadTask: Task<Void, Never>?
    private var pendingAchievementTask: Task<Void, Never>?
    private var completionTotalsByHabitDay: [UUID: [Date: Int]] = [:]
    
    init() {
        loadData()
    }

    // MARK: - Data Persistence
    private func loadData() {
        // Load from standard UserDefaults for main app
        if let habitsData = UserDefaults.standard.data(forKey: habitsKey),
           let decodedHabits = try? JSONDecoder().decode([Habit].self, from: habitsData) {
            habits = decodedHabits
        }
        
        if let completionsData = UserDefaults.standard.data(forKey: completionsKey),
           let decodedCompletions = try? JSONDecoder().decode([HabitCompletion].self, from: completionsData) {
            completions = decodedCompletions
        }
        rebuildCompletionTotals()
    }
    
    // MARK: - Data Refresh
    func refreshData() {
        // Try to load from App Group first (widget changes), then fallback to local
        loadFromAppGroup()
        
        // If App Group is empty, load from local storage
        if habits.isEmpty || completions.isEmpty {
            loadData()
        }
    }
    
    // MARK: - App Group Sync
    private func syncWithAppGroup() {
        // Sync habits with App Group storage
        if let appGroupDefaults = UserDefaults(suiteName: "group.com.Maicol.MiniHabitTracker") {
            if let encodedHabits = try? JSONEncoder().encode(habits) {
                appGroupDefaults.set(encodedHabits, forKey: "SavedHabits")
            }
            
            if let encodedCompletions = try? JSONEncoder().encode(completions) {
                appGroupDefaults.set(encodedCompletions, forKey: "SavedCompletions")
            }
        }
    }
    
    private func loadFromAppGroup() {
        // Load data from App Group storage
        if let appGroupDefaults = UserDefaults(suiteName: "group.com.Maicol.MiniHabitTracker") {
            if let habitData = appGroupDefaults.data(forKey: "SavedHabits"),
               let decodedHabits = try? JSONDecoder().decode([Habit].self, from: habitData) {
                habits = decodedHabits
            }
            
            if let completionData = appGroupDefaults.data(forKey: "SavedCompletions"),
               let decodedCompletions = try? JSONDecoder().decode([HabitCompletion].self, from: completionData) {
                completions = decodedCompletions
            }
        }
        rebuildCompletionTotals()
    }
    
    func saveData() {
        // Save to standard UserDefaults for main app
        if let encodedHabits = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encodedHabits, forKey: habitsKey)
        }
        
        if let encodedCompletions = try? JSONEncoder().encode(completions) {
            UserDefaults.standard.set(encodedCompletions, forKey: completionsKey)
        }
        
        // Also sync with App Group storage for widget access
        syncWithAppGroup()
    }
    
    // MARK: - Habit Management
    func addHabit(_ habit: Habit) {
        habits.append(habit)
        saveData()

        ReminderManager.shared.syncReminder(for: habit)
        
        // Refresh widget
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            saveData()

            ReminderManager.shared.syncReminder(for: habit)
            
            // Refresh widget
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        completions.removeAll { $0.habitId == habit.id }
        saveData()

        Task {
            await ReminderManager.shared.removeReminders(for: habit.id)
        }
        
        // Refresh widget
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func moveHabits(fromOffsets source: IndexSet, toOffset destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        saveData()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Date Management
    func updateSelectedDate() {
        selectedDate = Date()
    }
    
    // MARK: - Completion Management
    func addCompletion(for habitId: UUID, value: Int = 1, notes: String? = nil) {
        let currentDate = Date()
        let calendar = Calendar.current
        guard value > 0 else { return }
        let valueToAdd = value

        let hadCompletionToday = completions.contains { completion in
            completion.habitId == habitId && calendar.isDate(completion.date, inSameDayAs: currentDate)
        }
        let completion = HabitCompletion(habitId: habitId, date: currentDate, value: valueToAdd, notes: notes)
        completions.append(completion)
        addToCompletionTotals(completion)
        
        // Update habit statistics
        if let index = habits.firstIndex(where: { $0.id == habitId }) {
            habits[index].totalCompletions += valueToAdd
            habits[index].lastCompletedDate = currentDate
            if !hadCompletionToday {
                habits[index].streak = calculateCurrentStreak(for: habitId)
            }
        }
        
        // Coalesce rapid taps into one persistence write.
        scheduleDataSave()
        
        // Debounce expensive achievement scans during rapid taps.
        scheduleAchievementCheck()
        
        // Coalesce rapid taps into one widget refresh.
        scheduleWidgetReload()
    }
    
    func removeCompletion(_ completion: HabitCompletion) {
        completions.removeAll { $0.id == completion.id }
        removeFromCompletionTotals(completion)
        
        // Update habit statistics
        if let index = habits.firstIndex(where: { $0.id == completion.habitId }) {
            habits[index].totalCompletions = max(0, habits[index].totalCompletions - completion.value)
            habits[index].streak = calculateCurrentStreak(for: completion.habitId)
        }
        
        scheduleDataSave()
        
        // Refresh widget
        scheduleWidgetReload()
    }
    
    func removeCompletion(for habitId: UUID, on date: Date) {
        let calendar = Calendar.current
        let completionsToRemove = completions.filter { completion in
            completion.habitId == habitId &&
            calendar.isDate(completion.date, inSameDayAs: date)
        }
        
        for completion in completionsToRemove {
            removeCompletion(completion)
        }
        
        // Widget refresh is handled in removeCompletion
    }
    
    // MARK: - Statistics Calculation
    func getCompletions(for habitId: UUID) -> [HabitCompletion] {
        return completions.filter { $0.habitId == habitId }
    }
    
    func getCompletions(for habitId: UUID, on date: Date) -> [HabitCompletion] {
        let calendar = Calendar.current
        return completions.filter { completion in
            completion.habitId == habitId &&
            calendar.isDate(completion.date, inSameDayAs: date)
        }
    }
    
    func getTotalCompletions(for habitId: UUID, on date: Date) -> Int {
        let dayKey = Calendar.current.startOfDay(for: date)
        return completionTotalsByHabitDay[habitId]?[dayKey] ?? 0
    }

    func getRecentDailyTotals(for habitId: UUID, days: Int, endingOn endDate: Date = Date()) -> [Int] {
        let calendar = Calendar.current
        let totalsByDay = completionTotalsByHabitDay[habitId] ?? [:]
        let safeDays = max(1, days)

        return (0..<safeDays).map { index in
            let daysAgo = (safeDays - 1) - index
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: endDate) ?? endDate
            let dayKey = calendar.startOfDay(for: date)
            return totalsByDay[dayKey] ?? 0
        }
    }
    
    func isCompleted(for habitId: UUID, on date: Date) -> Bool {
        guard let habit = habits.first(where: { $0.id == habitId }) else { return false }
        let total = getTotalCompletions(for: habitId, on: date)
        if habit.usesTargetGoal {
            return total >= max(1, habit.target)
        }
        return total > 0
    }

    func todayProgressStats(on date: Date = Date()) -> TodayProgressStats {
        let activeHabits = habits.filter { $0.isActive }
        let activeHabitsCount = activeHabits.count
        let completedCount = activeHabits.filter { habit in
            isCompleted(for: habit.id, on: date)
        }.count
        let completionProgress = activeHabitsCount > 0
            ? Double(completedCount) / Double(activeHabitsCount)
            : 0.0

        return TodayProgressStats(
            activeHabitsCount: activeHabitsCount,
            completedCount: completedCount,
            completionProgress: completionProgress
        )
    }
    
    func calculateCurrentStreak(for habitId: UUID) -> Int {
        guard habits.contains(where: { $0.id == habitId }) else { return 0 }

        let calendar = Calendar.current
        let completedDays = uniqueCompletedDays(for: habitId, calendar: calendar)
        guard !completedDays.isEmpty else { return 0 }

        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())
        let completedDaySet = Set(completedDays)

        while completedDaySet.contains(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            currentDay = previousDay
        }

        return streak
    }
    
    func calculateLongestStreak(for habitId: UUID) -> Int {
        let calendar = Calendar.current
        let completedDays = uniqueCompletedDays(for: habitId, calendar: calendar)
        guard !completedDays.isEmpty else { return 0 }

        var longestStreak = 1
        var currentStreak = 1
        var previousDay = completedDays[0]

        for day in completedDays.dropFirst() {
            let daysBetween = calendar.dateComponents([.day], from: previousDay, to: day).day ?? 0
            if daysBetween == 1 {
                currentStreak += 1
            } else {
                longestStreak = max(longestStreak, currentStreak)
                currentStreak = 1
            }
            previousDay = day
        }

        return max(longestStreak, currentStreak)
    }

    private func uniqueCompletedDays(for habitId: UUID, calendar: Calendar) -> [Date] {
        Array(
            Set(getCompletions(for: habitId).map { completion in
                calendar.startOfDay(for: completion.date)
            })
        ).sorted()
    }
    
    func calculateCompletionRate(for habitId: UUID, in days: Int = 30) -> Double {
        guard habits.contains(where: { $0.id == habitId }) else { return 0.0 }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let completionsInRange = getCompletions(for: habitId).filter { completion in
            completion.date >= startDate && completion.date <= endDate
        }
        
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? days
        let completedDays = Set(completionsInRange.map { calendar.startOfDay(for: $0.date) }).count
        
        return totalDays > 0 ? Double(completedDays) / Double(totalDays) : 0.0
    }
    
    // MARK: - Widget Data
    func getWidgetData() -> [Habit] {
        return habits.filter { $0.isActive }.prefix(5).map { $0 }
    }
    
    func getTodayCompletions() -> Int {
        let calendar = Calendar.current
        return completions.filter { calendar.isDateInToday($0.date) }.count
    }
    
    func getWeeklyProgress() -> Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
        
        let activeHabits = habits.filter { $0.isActive }
        let totalPossibleCompletions = activeHabits.count * 7 // 7 days in a week
        
        let weekCompletions = completions.filter { completion in
            completion.date >= weekStart && completion.date < weekEnd
        }.count
        
        return totalPossibleCompletions > 0 ? Double(weekCompletions) / Double(totalPossibleCompletions) : 0.0
    }
    
    // MARK: - Data Import
    func importHabits(_ importedHabits: [Habit]) {
        habits = importedHabits
        saveData()
    }
    
    func importCompletions(_ importedCompletions: [HabitCompletion]) {
        completions = importedCompletions
        rebuildCompletionTotals()
        saveData()
    }

    private func rebuildCompletionTotals() {
        let calendar = Calendar.current
        var totals: [UUID: [Date: Int]] = [:]

        for completion in completions {
            let dayKey = calendar.startOfDay(for: completion.date)
            totals[completion.habitId, default: [:]][dayKey, default: 0] += completion.value
        }

        completionTotalsByHabitDay = totals
    }

    private func addToCompletionTotals(_ completion: HabitCompletion) {
        let dayKey = Calendar.current.startOfDay(for: completion.date)
        completionTotalsByHabitDay[completion.habitId, default: [:]][dayKey, default: 0] += completion.value
    }

    private func removeFromCompletionTotals(_ completion: HabitCompletion) {
        let dayKey = Calendar.current.startOfDay(for: completion.date)
        guard var byDay = completionTotalsByHabitDay[completion.habitId] else { return }
        let next = (byDay[dayKey] ?? 0) - completion.value
        if next > 0 {
            byDay[dayKey] = next
        } else {
            byDay.removeValue(forKey: dayKey)
        }
        completionTotalsByHabitDay[completion.habitId] = byDay
    }

    private func scheduleDataSave(delayNanoseconds: UInt64 = 250_000_000) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.saveData()
        }
    }

    private func scheduleWidgetReload(delayNanoseconds: UInt64 = 350_000_000) {
        pendingWidgetReloadTask?.cancel()
        pendingWidgetReloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func scheduleAchievementCheck(delayNanoseconds: UInt64 = 450_000_000) {
        pendingAchievementTask?.cancel()
        pendingAchievementTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled, let self else { return }
            AchievementManager.shared.checkAchievements(habitStore: self)
        }
    }
    
    // MARK: - Achievement Integration
    func checkAndUpdateAchievements() {
        AchievementManager.shared.checkAchievements(habitStore: self)
    }
} 
