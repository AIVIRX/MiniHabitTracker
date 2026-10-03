//
//  AppIntent.swift
//  Widgets
//
//  Created by Maicol Cabreja on 8/20/25.
//

import Foundation
import WidgetKit
import AppIntents

// MARK: - Habit Entity for Dynamic Selection
struct HabitEntity: AppEntity {
    let id: String
    let name: String
    let color: String
    
    var displayRepresentation: DisplayRepresentation {
        if id == "no-habits" {
            return DisplayRepresentation(
                title: "No habits available",
                subtitle: "Create habits in the main app first",
                image: .init(systemName: "plus.circle")
            )
        } else {
            return DisplayRepresentation(
                title: "\(name)",
                subtitle: "Tap to select this habit",
                image: .init(systemName: "checkmark.circle")
            )
        }
    }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static var defaultQuery = HabitQuery()
}

struct HabitQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        let habits = SharedDataManager.shared.loadHabits()
        return habits.compactMap { habit in
            guard identifiers.contains(habit.id.uuidString) else { return nil }
            return HabitEntity(
                id: habit.id.uuidString,
                name: habit.name,
                color: habit.color.rawValue
            )
        }
    }
    
    func suggestedEntities() async throws -> [HabitEntity] {
        let habits = SharedDataManager.shared.loadHabits()
        
        // If no habits exist, return a special "no habits" entity
        if habits.isEmpty {
            return [
                HabitEntity(
                    id: "no-habits",
                    name: "No habits available",
                    color: "gray"
                )
            ]
        }
        
        return habits.map { habit in
            HabitEntity(
                id: habit.id.uuidString,
                name: habit.name,
                color: habit.color.rawValue
            )
        }
    }
    
    func defaultResult() async -> HabitEntity? {
        let habits = SharedDataManager.shared.loadHabits()
        return habits.first.map { habit in
            HabitEntity(
                id: habit.id.uuidString,
                name: habit.name,
                color: habit.color.rawValue
            )
        }
    }
}

// MARK: - Enhanced Configuration Intent with Entity Support
struct EnhancedConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Habit Widget Configuration" }
    static var description: IntentDescription { "Configure which habit to display in the widget" }

    // Habit selection parameter with entity support
    @Parameter(title: "Selected Habit")
    var selectedHabit: HabitEntity?
    
    init() {
        // Ensure each new widget starts with no habit selected
        self.selectedHabit = nil
    }
    
    init(selectedHabit: HabitEntity?) {
        self.selectedHabit = selectedHabit
    }
    
    static var parameterSummary: some ParameterSummary {
        Summary("Configure widget for \(\.$selectedHabit)")
    }
}

struct LogHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Habit"
    static var description = IntentDescription("Log one completion for the selected habit.")

    @Parameter(title: "Habit")
    var habit: HabitEntity

    init() {}

    init(habit: HabitEntity) {
        self.habit = habit
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard habit.id != "no-habits", let habitUUID = UUID(uuidString: habit.id) else {
            return .result()
        }
        let today = Date()
        let allHabits = SharedDataManager.shared.loadHabits()
        let isGoalHabit = allHabits.first(where: { $0.id == habitUUID })?.usesTargetGoal ?? false
        let todayTotal = SharedDataManager.shared.totalCompletions(for: habitUUID, on: today)

        if isGoalHabit {
            // Goal habits: tap increments by 1.
            SharedDataManager.shared.addCompletion(for: habitUUID, value: 1)
        } else {
            // Binary habits: tap toggles today's completion.
            if todayTotal > 0 {
                SharedDataManager.shared.removeCompletion(for: habitUUID, on: today)
            } else {
                SharedDataManager.shared.addCompletion(for: habitUUID, value: 1)
            }
        }
        SharedDataManager.shared.setWidgetRipple(habitId: habitUUID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
