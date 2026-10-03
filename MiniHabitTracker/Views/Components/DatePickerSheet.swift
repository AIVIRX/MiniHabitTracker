import SwiftUI

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Date picker
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                // Quick date buttons
                HStack(spacing: 12) {
                    QuickDateButton(title: "Today", action: { selectedDate = Date() })
                    QuickDateButton(title: "Yesterday", action: { 
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                    })
                    QuickDateButton(title: "Tomorrow", action: { 
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    })
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QuickDateButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.opacity(0.1))
                )
        }
    }
}
