import Foundation
import SwiftUI
import UIKit

// MARK: - Habit Model
struct Habit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String

    var frequency: HabitFrequency
    var usesTargetGoal: Bool
    var target: Int
    var unit: String
    var color: HabitColor
    var customColorHex: String?
    var reminderTime: DateComponents?
    var reminderWeekdays: [Int]?
    var isActive: Bool
    var createdAt: Date
    var streak: Int
    var totalCompletions: Int
    var lastCompletedDate: Date?
    
    init(
        name: String,
        frequency: HabitFrequency = .daily,
        usesTargetGoal: Bool = false,
        target: Int = 1,
        unit: String = "Count",
        color: HabitColor = .blue,
        customColorHex: String? = nil,
        reminderTime: DateComponents? = nil,
        reminderWeekdays: [Int]? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.frequency = frequency
        self.usesTargetGoal = usesTargetGoal
        self.target = target
        self.unit = unit
        self.color = color
        self.customColorHex = customColorHex
        self.reminderTime = reminderTime
        self.reminderWeekdays = reminderWeekdays
        self.isActive = true
        self.createdAt = Date()
        self.streak = 0
        self.totalCompletions = 0
        self.lastCompletedDate = nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case frequency
        case usesTargetGoal
        case target
        case unit
        case color
        case customColorHex
        case reminderTime
        case reminderWeekdays
        case isActive
        case createdAt
        case streak
        case totalCompletions
        case lastCompletedDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        frequency = try container.decode(HabitFrequency.self, forKey: .frequency)
        target = try container.decode(Int.self, forKey: .target)
        unit = try container.decode(String.self, forKey: .unit)
        usesTargetGoal = try container.decodeIfPresent(Bool.self, forKey: .usesTargetGoal) ?? true
        color = try container.decode(HabitColor.self, forKey: .color)
        customColorHex = try container.decodeIfPresent(String.self, forKey: .customColorHex)
        reminderTime = try container.decodeIfPresent(DateComponents.self, forKey: .reminderTime)
        reminderWeekdays = try container.decodeIfPresent([Int].self, forKey: .reminderWeekdays)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        streak = try container.decode(Int.self, forKey: .streak)
        totalCompletions = try container.decode(Int.self, forKey: .totalCompletions)
        lastCompletedDate = try container.decodeIfPresent(Date.self, forKey: .lastCompletedDate)
    }

    var displayColor: Color {
        if color == .custom, let customColorHex, let custom = Color(hex: customColorHex) {
            return custom
        }
        return color.color
    }
}



// MARK: - Habit Frequency
enum HabitFrequency: String, CaseIterable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"
    
    var description: String {
        switch self {
        case .daily: return "Every day"
        case .weekly: return "Every week"
        case .monthly: return "Every month"
        case .custom: return "Custom schedule"
        }
    }
}

// MARK: - Habit Color
enum HabitColor: String, CaseIterable, Codable {
    case custom = "Custom"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case indigo = "Indigo"
    case teal = "Teal"
    case brown = "Brown"
    case gray = "Gray"
    
    var color: Color {
        switch self {
        case .custom: return .blue
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .indigo: return .indigo
        case .teal: return .teal
        case .brown: return .brown
        case .gray: return .gray
        }
    }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let int = Int(cleaned, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }

    var hexString: String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(format: "#%02lX%02lX%02lX", lround(Double(red * 255)), lround(Double(green * 255)), lround(Double(blue * 255)))
    }
}

// MARK: - Habit Completion
struct HabitCompletion: Identifiable, Codable {
    let id: UUID
    let habitId: UUID
    let date: Date
    let value: Int
    let notes: String?
    
    init(habitId: UUID, date: Date = Date(), value: Int = 1, notes: String? = nil) {
        self.id = UUID()
        self.habitId = habitId
        self.date = date
        self.value = value
        self.notes = notes
    }
}

 
