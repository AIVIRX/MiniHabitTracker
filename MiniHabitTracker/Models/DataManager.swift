import Foundation
import SwiftUI

// MARK: - Shared Data Manager for App Groups
class SharedDataManager {
    static let shared = SharedDataManager()
    
    // App Group identifier - you'll need to add this in Xcode project settings
    private let appGroupIdentifier = "group.com.Maicol.MiniHabitTracker"
    
    private var userDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    private init() {}
    
    // MARK: - Habit Data
    func saveHabits(_ habits: [Habit]) {
        if let encodedHabits = try? JSONEncoder().encode(habits) {
            userDefaults?.set(encodedHabits, forKey: "SavedHabits")
        }
    }
    
    func loadHabits() -> [Habit] {
        guard let habitData = userDefaults?.data(forKey: "SavedHabits"),
              let decodedHabits = try? JSONDecoder().decode([Habit].self, from: habitData) else {
            return []
        }
        return decodedHabits
    }
    
    // MARK: - Completion Data
    func saveCompletions(_ completions: [HabitCompletion]) {
        if let encodedCompletions = try? JSONEncoder().encode(completions) {
            userDefaults?.set(encodedCompletions, forKey: "SavedCompletions")
        }
    }
    
    func loadCompletions() -> [HabitCompletion] {
        guard let completionData = userDefaults?.data(forKey: "SavedCompletions"),
              let decodedCompletions = try? JSONDecoder().decode([HabitCompletion].self, from: completionData) else {
            return []
        }
        return decodedCompletions
    }
    

} 
