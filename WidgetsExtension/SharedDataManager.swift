//
//  SharedDataManager.swift
//  Widgets
//
//  Created by Maicol Cabreja on 8/20/25.
//

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
    private let widgetRippleHabitIdKey = "WidgetRippleHabitID"
    private let widgetRippleTimestampKey = "WidgetRippleTimestamp"
    
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
    
    // MARK: - Completion Management
    func addCompletion(for habitId: UUID, value: Int) {
        var completions = loadCompletions()
        let today = Date()
        
        // Check if completion already exists for today
        if let existingIndex = completions.firstIndex(where: { completion in
            completion.habitId == habitId &&
            Calendar.current.isDate(completion.date, inSameDayAs: today)
        }) {
            // Remove existing completion and create new one with updated value
            let existingCompletion = completions[existingIndex]
            let newValue = existingCompletion.value + value
            completions.remove(at: existingIndex)
            
            let updatedCompletion = HabitCompletion(
                id: existingCompletion.id,
                habitId: habitId,
                date: today,
                value: newValue,
                notes: existingCompletion.notes
            )
            completions.append(updatedCompletion)
        } else {
            // Create new completion
            let newCompletion = HabitCompletion(
                id: UUID(),
                habitId: habitId,
                date: today,
                value: value,
                notes: nil
            )
            completions.append(newCompletion)
        }
        
        saveCompletions(completions)
    }
    
    func removeCompletion(for habitId: UUID, on date: Date) {
        var completions = loadCompletions()
        
        // Remove completion for the specific date
        completions.removeAll { completion in
            completion.habitId == habitId &&
            Calendar.current.isDate(completion.date, inSameDayAs: date)
        }
        
        saveCompletions(completions)
    }

    func totalCompletions(for habitId: UUID, on date: Date) -> Int {
        let calendar = Calendar.current
        return loadCompletions()
            .filter { $0.habitId == habitId && calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + max(0, $1.value) }
    }

    func decrementCompletion(for habitId: UUID, value: Int = 1, on date: Date = Date()) {
        guard value > 0 else { return }
        var completions = loadCompletions()
        let calendar = Calendar.current

        guard let existingIndex = completions.firstIndex(where: { completion in
            completion.habitId == habitId && calendar.isDate(completion.date, inSameDayAs: date)
        }) else {
            return
        }

        let existing = completions[existingIndex]
        let newValue = max(0, existing.value - value)
        completions.remove(at: existingIndex)

        if newValue > 0 {
            let updated = HabitCompletion(
                id: existing.id,
                habitId: existing.habitId,
                date: existing.date,
                value: newValue,
                notes: existing.notes
            )
            completions.append(updated)
        }

        saveCompletions(completions)
    }

    func setWidgetRipple(habitId: UUID, date: Date = Date()) {
        userDefaults?.set(habitId.uuidString, forKey: widgetRippleHabitIdKey)
        userDefaults?.set(date.timeIntervalSince1970, forKey: widgetRippleTimestampKey)
    }

    func widgetRippleState() -> (habitId: String, date: Date)? {
        guard
            let habitId = userDefaults?.string(forKey: widgetRippleHabitIdKey),
            let timestamp = userDefaults?.object(forKey: widgetRippleTimestampKey) as? Double
        else { return nil }
        return (habitId, Date(timeIntervalSince1970: timestamp))
    }
}
