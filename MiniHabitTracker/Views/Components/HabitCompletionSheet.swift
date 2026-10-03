import SwiftUI

struct HabitCompletionSheet: View {
    let habit: Habit
    @Environment(HabitStore.self) private var habitStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var completionValue: Int = 1
    @State private var notes: String = ""
    @State private var selectedDate = Date()
    
    // Update selectedDate to current date when view appears
    private func updateDateToCurrent() {
        selectedDate = Date()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(habit.displayColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundColor(habit.displayColor)
                    }
                    
                    Text(habit.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Add completion for today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Completion value picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("How many times?")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        Button(action: { decrementValue() }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .disabled(completionValue <= 1)
                        
                        Text("\(completionValue)")
                            .font(.title)
                            .fontWeight(.bold)
                            .frame(minWidth: 60)
                        
                        Button(action: { incrementValue() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text("Entries")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                
                // Notes field
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes (optional)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Add a note about this completion...", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                // Date picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: addCompletion) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Add Completion")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(habit.displayColor)
                        )
                    }
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .navigationTitle("Add Completion")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updateDateToCurrent()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func incrementValue() {
        completionValue += 1
    }
    
    private func decrementValue() {
        if completionValue > 1 {
            completionValue -= 1
        }
    }
    
    private func addCompletion() {
        habitStore.addCompletion(
            for: habit.id,
            value: completionValue,
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}
