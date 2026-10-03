import SwiftUI

struct WeekOverviewView: View {
    let selectedDate: Date
    @Environment(HabitStore.self) private var habitStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(weekCompletionCount)/\(weekTotalPossible)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Week progress bars
            LazyVStack(spacing: 6) {
                ForEach(activeHabits) { habit in
                    WeekHabitRow(habit: habit, weekDates: weekDates)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var activeHabits: [Habit] {
        habitStore.habits.filter { $0.isActive }
    }
    
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }
    
    private var weekCompletionCount: Int {
        let activeHabits = habitStore.habits.filter { $0.isActive }
        var totalCompletions = 0
        
        for habit in activeHabits {
            for date in weekDates {
                if habitStore.isCompleted(for: habit.id, on: date) {
                    totalCompletions += 1
                }
            }
        }
        
        return totalCompletions
    }
    
    private var weekTotalPossible: Int {
        activeHabits.count * 7
    }
}

struct WeekHabitRow: View {
    let habit: Habit
    let weekDates: [Date]
    @Environment(HabitStore.self) private var habitStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Habit icon
            ZStack {
                Circle()
                    .fill(habit.displayColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(habit.displayColor)
            }
            
            // Habit name
            Text(habit.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            // Week progress dots
            HStack(spacing: 4) {
                ForEach(weekDates, id: \.self) { date in
                    Circle()
                        .fill(isCompleted(for: date) ? habit.displayColor : Color(.systemGray5))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Completion count
            Text("\(weekCompletionCount)/7")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func isCompleted(for date: Date) -> Bool {
        habitStore.isCompleted(for: habit.id, on: date)
    }
    
    private var weekCompletionCount: Int {
        weekDates.filter { isCompleted(for: $0) }.count
    }
}
