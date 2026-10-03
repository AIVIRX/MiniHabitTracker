import SwiftUI
import Foundation

// MARK: - Shared Heatmap Color Utility
struct HeatmapColorUtility {
    static let noDataTileColor: Color = Color.gray.opacity(0.2)
    static let minimumProgressOpacity: Double = 0.3

    static func clampedProgressOpacity(_ intensity: Double) -> Double {
        guard intensity > 0 else { return 0 }
        return max(minimumProgressOpacity, min(1.0, intensity))
    }

    @MainActor
    private static func completionIntensity(for habitStore: HabitStore, habitId: UUID, on date: Date) -> Double {
        guard let habit = habitStore.habits.first(where: { $0.id == habitId }) else { return 0.0 }
        let total = habitStore.getTotalCompletions(for: habitId, on: date)

        if habit.usesTargetGoal {
            let target = max(1, habit.target)
            return min(1.0, Double(total) / Double(target))
        }

        return total > 0 ? 1.0 : 0.0
    }

    // MARK: - Real Data, binary completion color
    @MainActor static func heatmapColorReal(habitStore: HabitStore, habitId: UUID, week: Int, day: Int, habitColor: Color) -> Color {
        let calendar = Calendar.current
        let today = Date()
        let weeksAgo = 8 - week
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart) ?? today
        let targetDate = calendar.date(byAdding: .day, value: day, to: targetWeekStart) ?? today
        if targetDate > today { return Color.clear }
        let daysAgo = calendar.dateComponents([.day], from: targetDate, to: today).day ?? 0
        if daysAgo > 62 { return Color.clear }
        let intensity = completionIntensity(for: habitStore, habitId: habitId, on: targetDate)
        return intensity > 0 ? habitColor.opacity(clampedProgressOpacity(intensity)) : noDataTileColor
    }
    

    
    // MARK: - Realistic Habit Pattern for AddHabitView preview
    private static func realisticHabitPattern(for week: Int, day: Int) -> Bool {
        // Create a truly realistic pattern that mimics real habit data
        // Use week and day as seed for consistency
        let seed = week * 7 + day
        
        // Simulate realistic habit building with natural variation
        let random = (seed * 9301 + 49297) % 233280
        
        // Add some natural variation based on day of week (people often struggle on weekends)
        let dayOfWeek = day
        let isWeekend = dayOfWeek == 0 || dayOfWeek == 6 // Sunday or Saturday
        
        // Base completion rates with natural progression - INCREASED for fuller look
        let baseRate: Int
        if week >= 7 {
            // Current week - established habit
            baseRate = isWeekend ? 5 : 5 // 83% weekdays, 83% weekends
        } else if week >= 6 {
            // Last week - peak consistency
            baseRate = isWeekend ? 5 : 5 // 83% weekdays, 83% weekends
        } else if week >= 5 {
            // Week 5 - good consistency
            baseRate = isWeekend ? 4 : 5 // 83% weekdays, 67% weekends
        } else if week >= 4 {
            // Week 4 - building consistency
            baseRate = isWeekend ? 4 : 5 // 83% weekdays, 67% weekends
        } else if week >= 3 {
            // Week 3 - moderate improvement
            baseRate = isWeekend ? 3 : 4 // 67% weekdays, 50% weekends
        } else if week >= 2 {
            // Week 2 - early struggle
            baseRate = isWeekend ? 3 : 4 // 67% weekdays, 50% weekends
        } else {
            // Week 1 - very early, mostly misses
            baseRate = isWeekend ? 2 : 3 // 50% weekdays, 33% weekends
        }
        
        // Create streaks by making consecutive days more likely to be completed
        let streakBonus = calculateStreakBonus(week: week, day: day, baseRate: baseRate)
        let finalRate = min(5, baseRate + streakBonus) // Cap at 5 (83% max)
        
        // Add some randomness to avoid perfect patterns
        let adjustedRandom = (random + (week * 13) + (day * 7)) % 233280
        
        return adjustedRandom % 6 < finalRate
    }
    
    // MARK: - Streak Bonus Calculation
    private static func calculateStreakBonus(week: Int, day: Int, baseRate: Int) -> Int {
        // If this is the first day of the week, no streak bonus
        if day == 0 {
            return 0
        }
        
        // Check if previous day was completed (simulate streak effect)
        let previousDaySeed = week * 7 + (day - 1)
        let previousRandom = (previousDaySeed * 9301 + 49297) % 233280
        let previousDayCompleted = previousRandom % 6 < baseRate
        
        // If previous day was completed, add streak bonus
        if previousDayCompleted {
            // Stronger streak bonus for established habits (later weeks)
            if week >= 5 {
                return 3 // Very strong streak bonus for established habits
            } else if week >= 3 {
                return 2 // Strong streak bonus for building habits
            } else {
                return 1 // Light streak bonus even for early weeks
            }
        }
        
        return 0
    }
    
    // MARK: - Get Heatmap Color for Date (Binary - On/Off only) - DETERMINISTIC for AddHabitView preview
    static func heatmapColor(for week: Int, day: Int, habitColor: Color, isToday: Bool = false) -> Color {
        let calendar = Calendar.current
        let today = Date()
        
        // Calculate the date for this specific week and day (60 days back)
        let weeksAgo = 8 - week // 8 weeks ago to current week
        
        // Get the start of the current week (Sunday)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        // Calculate the target week start by going back weeksAgo weeks
        let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeekStart) ?? today
        
        // Get the specific day of the week
        let targetDate = calendar.date(byAdding: .day, value: day, to: targetWeekStart) ?? today
        
        // Check if this date is in the future (for current week)
        if targetDate > today {
            return Color.clear // Hide future days
        }
        
        // Check if we're beyond 60 days
        let daysAgo = calendar.dateComponents([.day], from: targetDate, to: today).day ?? 0
        if daysAgo > 62 {
            return Color.clear // Hide days beyond 60
        }
        
        // Special case: make sure today is always visible and prominent
        if isToday {
            return habitColor.opacity(1.0) // Full opacity for today
        }
        
        // Deterministic random for preview - same pattern every time
        let hasActivity = realisticHabitPattern(for: week, day: day)
        return hasActivity ? habitColor : noDataTileColor
    }
    
    // MARK: - Get Heatmap Color for Mini Calendar (7 days) - DETERMINISTIC for AddHabitView preview
    static func heatmapColorForMiniCalendar(for day: Int, habitColor: Color, isToday: Bool = false) -> Color {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the date for this specific day (7 days back)
        let daysAgo = 6 - day // 6 days ago to today
        
        let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        
        // Check if this date is in the future
        if targetDate > today {
            return Color.clear
        }
        
        // Check if we're beyond 7 days
        let daysDifference = calendar.dateComponents([.day], from: targetDate, to: today).day ?? 0
        if daysDifference > 6 {
            return Color.clear
        }
        
        // Special case: make sure today is always visible and prominent
        if isToday {
            return habitColor.opacity(1.0) // Full opacity for today
        }
        
        // Deterministic random for preview - same pattern every time
        let hasActivity = realisticHabitPattern(for: 0, day: day) // Use week 0 for mini calendar
        return hasActivity ? habitColor : noDataTileColor
    }
    

    

    
    // MARK: - Get Heatmap Color for Mini Calendar Main View with Real Data
    @MainActor static func heatmapColorForMiniCalendarMainViewReal(habitStore: HabitStore, habitId: UUID, for day: Int, habitColor: Color, isToday: Bool = false) -> Color {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the date for this specific day (7 days back)
        let daysAgo = 6 - day // 6 days ago to today
        
        let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        
        // Check if this date is in the future
        if targetDate > today {
            return Color.clear
        }
        
        // Check if we're beyond 7 days
        let daysDifference = calendar.dateComponents([.day], from: targetDate, to: today).day ?? 0
        if daysDifference > 6 {
            return Color.clear
        }
        
        // Special case: make sure today is always visible and prominent
        if isToday {
            return habitColor.opacity(1.0) // Full opacity for today
        }
        
        // Use real completion data with intensity scaling for goal-based habits
        let intensity = completionIntensity(for: habitStore, habitId: habitId, on: targetDate)
        return intensity > 0 ? habitColor.opacity(clampedProgressOpacity(intensity)) : noDataTileColor
}
}
