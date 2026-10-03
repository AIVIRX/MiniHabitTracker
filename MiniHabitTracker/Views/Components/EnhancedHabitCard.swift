import SwiftUI

struct EnhancedHabitCard: View {
    let habit: Habit
    let selectedDate: Date
    let onToggle: () -> Void
    let onTap: () -> Void
    
    @Environment(HabitStore.self) private var habitStore
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon and Color
                ZStack {
                    Circle()
                        .fill(habit.displayColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundColor(habit.displayColor)
                }
                
                // Habit Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(habit.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if habit.streak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                Text("\(habit.streak)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    

                    
                    HStack(spacing: 8) {
                        
                        // Date-specific completion info
                        if isCompleted {
                            Text("Completed")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        } else {
                            Text("\(habit.totalCompletions)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Enhanced Completion Button
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? habit.displayColor : Color(.systemGray5))
                            .frame(width: 32, height: 32)
                        
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isCompleted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCompleted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isCompleted ? habit.displayColor.opacity(0.3) : Color(.separator), lineWidth: isCompleted ? 2 : 0.5)
                    )
                    .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isCompleted: Bool {
        habitStore.isCompleted(for: habit.id, on: selectedDate)
    }
}
