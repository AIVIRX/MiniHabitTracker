import Foundation
import SwiftUI

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    @Published var unlockedAchievements: Set<AchievementType> = []
    @Published var recentAchievements: [AchievementType] = []
    
    private let userDefaults = UserDefaults.standard
    private let achievementsKey = "UnlockedAchievements"
    private let recentAchievementsKey = "RecentAchievements"
    
    init() {
        loadAchievements()
    }
    
    // MARK: - Achievement Types
    enum AchievementType: String, CaseIterable {
        case firstHabit = "First Habit"
        case habitMaster = "Habit Master"
        case consistency = "Consistency"
        case dedication = "Dedication"
        case activeLifestyle = "Active Lifestyle"
        case streakMaster = "Streak Master"
        case perfectWeek = "Perfect Week"
        case monthlyMaster = "Monthly Master"
        case earlyBird = "Early Bird"
        case nightOwl = "Night Owl"
        case socialButterfly = "Social Butterfly"
        case fitnessGuru = "Fitness Guru"
        case bookworm = "Bookworm"
        case mindfulnessGuru = "Mindfulness Guru"
        case financeWizard = "Finance Wizard"
        
        var description: String {
            switch self {
            case .firstHabit: return "Create your first habit"
            case .habitMaster: return "Create 5 habits"
            case .consistency: return "Complete a habit 7 days in a row"
            case .dedication: return "Complete 100 total habits"
            case .activeLifestyle: return "Have 3 active habits"
            case .streakMaster: return "Maintain a 30-day streak"
            case .perfectWeek: return "Complete all habits for 7 consecutive days"
            case .monthlyMaster: return "Complete 90% of habits in a month"
            case .earlyBird: return "Complete a habit before 8 AM"
            case .nightOwl: return "Complete a habit after 10 PM"
            case .socialButterfly: return "Create 3 social habits"
            case .fitnessGuru: return "Complete 50 fitness habits"
            case .bookworm: return "Complete 25 learning habits"
            case .mindfulnessGuru: return "Complete 30 mindfulness habits"
            case .financeWizard: return "Complete 20 finance habits"
            }
        }
        
        var icon: String {
            switch self {
            case .firstHabit: return "plus.circle.fill"
            case .habitMaster: return "list.bullet.circle.fill"
            case .consistency: return "flame.fill"
            case .dedication: return "checkmark.circle.fill"
            case .activeLifestyle: return "figure.run"
            case .streakMaster: return "trophy.fill"
            case .perfectWeek: return "star.fill"
            case .monthlyMaster: return "calendar.circle.fill"
            case .earlyBird: return "sunrise.fill"
            case .nightOwl: return "moon.fill"
            case .socialButterfly: return "person.2.fill"
            case .fitnessGuru: return "dumbbell.fill"
            case .bookworm: return "book.fill"
            case .mindfulnessGuru: return "brain.head.profile"
            case .financeWizard: return "dollarsign.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .firstHabit: return .blue
            case .habitMaster: return .green
            case .consistency: return .orange
            case .dedication: return .purple
            case .activeLifestyle: return .red
            case .streakMaster: return .yellow
            case .perfectWeek: return .pink
            case .monthlyMaster: return .indigo
            case .earlyBird: return .orange
            case .nightOwl: return .purple
            case .socialButterfly: return .pink
            case .fitnessGuru: return .green
            case .bookworm: return .blue
            case .mindfulnessGuru: return .teal
            case .financeWizard: return .yellow
            }
        }
    }
    
    @MainActor
    func checkAchievements(habitStore: HabitStore) {
        let totalHabits = habitStore.habits.count
        let activeHabits = habitStore.habits.filter { $0.isActive }.count
        let totalCompletions = habitStore.completions.count
        let maxStreak = habitStore.habits.map { $0.streak }.max() ?? 0
        
        // Check each achievement
        checkFirstHabit(totalHabits)
        checkHabitMaster(totalHabits)
        checkConsistency(maxStreak)
        checkDedication(totalCompletions)
        checkActiveLifestyle(activeHabits)
        checkStreakMaster(maxStreak)
        checkPerfectWeek(habitStore)
        checkMonthlyMaster(habitStore)
        checkTimeBasedAchievements(habitStore)
    }
    
    private func checkFirstHabit(_ totalHabits: Int) {
        if totalHabits > 0 {
            unlockAchievement(.firstHabit)
        }
    }
    
    private func checkHabitMaster(_ totalHabits: Int) {
        if totalHabits >= 5 {
            unlockAchievement(.habitMaster)
        }
    }
    
    private func checkConsistency(_ maxStreak: Int) {
        if maxStreak >= 7 {
            unlockAchievement(.consistency)
        }
    }
    
    private func checkDedication(_ totalCompletions: Int) {
        if totalCompletions >= 100 {
            unlockAchievement(.dedication)
        }
    }
    
    private func checkActiveLifestyle(_ activeHabits: Int) {
        if activeHabits >= 3 {
            unlockAchievement(.activeLifestyle)
        }
    }
    
    private func checkStreakMaster(_ maxStreak: Int) {
        if maxStreak >= 30 {
            unlockAchievement(.streakMaster)
        }
    }
    
    @MainActor
    private func checkPerfectWeek(_ habitStore: HabitStore) {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
        
        let activeHabits = habitStore.habits.filter { $0.isActive }
        let weekCompletions = habitStore.completions.filter { completion in
            completion.date >= weekStart && completion.date < weekEnd
        }
        
        let totalPossible = activeHabits.count * 7
        let completionRate = totalPossible > 0 ? Double(weekCompletions.count) / Double(totalPossible) : 0.0
        
        if completionRate >= 1.0 {
            unlockAchievement(.perfectWeek)
        }
    }
    
    @MainActor
    private func checkMonthlyMaster(_ habitStore: HabitStore) {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let monthEnd = calendar.dateInterval(of: .month, for: Date())?.end ?? Date()
        
        let activeHabits = habitStore.habits.filter { $0.isActive }
        let monthCompletions = habitStore.completions.filter { completion in
            completion.date >= monthStart && completion.date < monthEnd
        }
        
        let totalPossible = activeHabits.count * 30
        let completionRate = totalPossible > 0 ? Double(monthCompletions.count) / Double(totalPossible) : 0.0
        
        if completionRate >= 0.9 {
            unlockAchievement(.monthlyMaster)
        }
    }
    
    @MainActor
    private func checkTimeBasedAchievements(_ habitStore: HabitStore) {
        let calendar = Calendar.current
        
        let earlyCompletions = habitStore.completions.filter { completion in
            let hour = calendar.component(.hour, from: completion.date)
            return hour < 8
        }
        
        let lateCompletions = habitStore.completions.filter { completion in
            let hour = calendar.component(.hour, from: completion.date)
            return hour >= 22
        }
        
        if !earlyCompletions.isEmpty {
            unlockAchievement(.earlyBird)
        }
        if !lateCompletions.isEmpty {
            unlockAchievement(.nightOwl)
        }
    }
    
    private func unlockAchievement(_ achievement: AchievementType) {
        if !unlockedAchievements.contains(achievement) {
            unlockedAchievements.insert(achievement)
            recentAchievements.insert(achievement, at: 0)
            
            // Keep only last 5 recent achievements
            if recentAchievements.count > 5 {
                recentAchievements = Array(recentAchievements.prefix(5))
            }
            
            saveAchievements()
        }
    }
    
    private func saveAchievements() {
        let achievementStrings = unlockedAchievements.map { $0.rawValue }
        userDefaults.set(achievementStrings, forKey: achievementsKey)
        
        let recentStrings = recentAchievements.map { $0.rawValue }
        userDefaults.set(recentStrings, forKey: recentAchievementsKey)
    }
    
    private func loadAchievements() {
        if let achievementStrings = userDefaults.stringArray(forKey: achievementsKey) {
            unlockedAchievements = Set(achievementStrings.compactMap { AchievementType(rawValue: $0) })
        }
        
        if let recentStrings = userDefaults.stringArray(forKey: recentAchievementsKey) {
            recentAchievements = recentStrings.compactMap { AchievementType(rawValue: $0) }
        }
    }
    
    func resetAchievements() {
        unlockedAchievements.removeAll()
        recentAchievements.removeAll()
        saveAchievements()
    }
} 
