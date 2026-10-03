import SwiftUI
import UserNotifications
import UIKit

struct AddHabitView: View {
    @Environment(HabitStore.self) private var habitStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name = ""
    @State private var selectedColor: HabitColor = .blue
    @State private var selectedCustomColor: Color = .blue
    @State private var colorWaveTrigger: Int = 0
    @State private var usesTargetGoal = false
    @State private var target = 1
    @State private var remindersEnabled = false
    @State private var reminderTime = Date()
    @State private var selectedReminderWeekdays: Set<Int> = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                (colorScheme == .light ? Color.secondary.opacity(0.2) : Color.black)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Progress Preview Card
                        ProgressPreviewCard(
                            habit: previewHabit,
                            selectedColor: selectedColorValue,
                            externalWaveTrigger: colorWaveTrigger
                        )
                        
                        // Habit Name Input Section
                        HabitNameSection(name: $name, selectedColor: selectedColor)
                        
                        // Color Selection
                        ColorSelectionSection(
                            selectedColor: $selectedColor,
                            selectedCustomColor: $selectedCustomColor
                        )

                        TargetUnitSection(
                            usesTargetGoal: $usesTargetGoal,
                            target: $target
                        )

                        ReminderSection(
                            remindersEnabled: $remindersEnabled,
                            reminderTime: $reminderTime,
                            selectedWeekdays: $selectedReminderWeekdays,
                            selectedColor: selectedColorValue
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: selectedColor) {
                colorWaveTrigger += 1
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button{
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .tint(.orange)

                            .font(.headline.weight(.semibold))
                            
                    }
                }
                
                
                ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveHabit()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.headline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(selectedColorValue)
                        .opacity(name.isEmpty ? 0.45 : 1.0)
                        .disabled(name.isEmpty)
                        .id(selectedColor.rawValue + (selectedCustomColor.hexString ?? ""))
                }
            }
        }
    }
    
    private var previewHabit: Habit {
        Habit(
            name: name.isEmpty ? "Habit" : name,
            frequency: .daily,
            usesTargetGoal: usesTargetGoal,
            target: target,
            unit: "Count",
            color: selectedColor,
            customColorHex: selectedColor == .custom ? selectedCustomColor.hexString : nil
        )
    }
    
    private func saveHabit() {
        let habit = Habit(
            name: name,
            frequency: .daily,
            usesTargetGoal: usesTargetGoal,
            target: target,
            unit: "Count",
            color: selectedColor,
            customColorHex: selectedColor == .custom ? selectedCustomColor.hexString : nil,
            reminderTime: remindersEnabled ? Calendar.current.dateComponents([.hour, .minute], from: reminderTime) : nil,
            reminderWeekdays: remindersEnabled ? selectedReminderWeekdays.sorted() : nil
        )
        
        habitStore.addHabit(habit)
        requestReview()
        dismiss()
    }

    private var selectedColorValue: Color {
        selectedColor == .custom ? selectedCustomColor : selectedColor.color
    }
}

struct ProgressPreviewCard: View {
    let habit: Habit
    let selectedColor: Color
    let externalWaveTrigger: Int
    
    @State private var trigger: Int = 0
    @State private var waveOrigin: CGPoint = CGPoint(x: 4, y: 3) // Default to center of calendar
    @State private var isTodayCompleted: Bool = false // Demo completion state
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            // Left side: Calendar
            VStack(spacing: 0) {
                // GitHub-style Heatmap (Horizontal Layout)
                HStack(spacing: 5) {
                    // Day labels (GitHub style - vertical, localized)
                    VStack(spacing: 2.5) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            Text(DateUtils.localizedDayAbbreviation(dayIndex: dayIndex))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(height: 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(width: 20) // Match widget medium label width
                    
                    // Heatmap grid (8.5 weeks horizontally for ~60 days)
                        HStack(spacing: 2.5) {
                        ForEach(0..<9, id: \.self) { week in
                            VStack(spacing: 2.5) {
                                ForEach(0..<7, id: \.self) { day in
                                    // Week 8 (rightmost) should contain today and show all days up to today
                                    if week < 8 {
                                        // Full weeks
                                        AnimatedCalendarSquare(
                                            week: week,
                                            day: day,
                                            waveOrigin: waveOrigin,
                                            trigger: trigger,
                                            heatmapColor: HeatmapColorUtility.heatmapColor(for: week, day: day, habitColor: selectedColor),
                                            size: 14
                                        )
                                        .onTapGesture {
                                            // Update wave origin first, then trigger animation
                                            waveOrigin = CGPoint(x: Double(week), y: Double(day))
                                            trigger += 1
                                            HapticManager.shared.playWaveBounce()
                                        }
                                    } else if week == 8 {
                                        // Current week - show all days up to today
                                        let calendar = Calendar.current
                                        let today = Date()
                                        let currentDayOfWeek = calendar.component(.weekday, from: today) - 1 // 0=Sunday, 1=Monday, etc.
                                        
                                        if day <= currentDayOfWeek {
                                            // Show this day (including today)
                                            AnimatedCalendarSquare(
                                                week: week,
                                                day: day,
                                                waveOrigin: waveOrigin,
                                                trigger: trigger,
                                                heatmapColor: day == currentDayOfWeek ? 
                                                    (isTodayCompleted ? selectedColor : Color.clear) :
                                                    HeatmapColorUtility.heatmapColor(for: week, day: day, habitColor: selectedColor),
                                                size: 14
                                            )
                                            .overlay(
                                                // Match widget-style today outline
                                                Group {
                                                    if day == currentDayOfWeek {
                                                        // Check if today has activity data
                                                        let hasActivity = isTodayCompleted
                                                        
                                                        if !hasActivity {
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .stroke(
                                                                    selectedColor,
                                                                    lineWidth: 1.8
                                                                )
                                                                .frame(width: 14, height: 14)
                                                        }
                                                    }
                                                }
                                            )
                                            .onTapGesture {
                                                // Update wave origin first, then trigger animation
                                                waveOrigin = CGPoint(x: Double(week), y: Double(day))
                                                trigger += 1
                                                HapticManager.shared.playWaveBounce()
                                            }
                                        } else {
                                            // Hide future days in current week
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.clear)
                                                .frame(width: 14, height: 14)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right side: Habit Info & Actions
            VStack(spacing: 8) {
                
                
                // Habit name - aligned to the right
                HStack {
                    Text(habit.name.isEmpty ? "Habit" : habit.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                // Streak information instead of completion status
                HStack {
                    Text("25 day streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                Spacer()
                
                // CHECK IN button at bottom - aligned to the right
                HStack {
                    Spacer()
                    Button(action: {
                        // Toggle demo completion state
                        isTodayCompleted.toggle()
                        
                        // Set wave origin to today's position
                        let calendar = Calendar.current
                        let today = Date()
                        let currentDayOfWeek = calendar.component(.weekday, from: today) - 1
                        waveOrigin = CGPoint(x: 8, y: Double(currentDayOfWeek)) // Week 8, current day
                        
                        // Trigger the wave animation
                        trigger += 1
                        HapticManager.shared.playWaveBounce()
                    }) {
                        HStack(spacing: 8) {
                            if habit.usesTargetGoal {
                                if isTodayCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.callout)
                                        .foregroundColor(.white)
                                } else {
                                    Text("1/\(max(1, habit.target))")
                                        .font(.caption.bold())
                                        .monospacedDigit()
                                        .foregroundColor(.white)
                                }
                            } else {
                                Image(systemName: isTodayCompleted ? "checkmark.circle.fill" : "plus")
                                    .font(.callout)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isTodayCompleted ? selectedColor : Color(.systemGray4))
                        )
                    }
                }
            }
            .frame(maxWidth: 140, alignment: .trailing)
        }
        .frame(height: 130)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
        )
        .frame(maxWidth: .infinity)
        .onChange(of: externalWaveTrigger) {
            let calendar = Calendar.current
            let today = Date()
            let currentDayOfWeek = calendar.component(.weekday, from: today) - 1
            waveOrigin = CGPoint(x: 8, y: Double(currentDayOfWeek))
            trigger += 1
        }
    }
}

struct HabitNameSection: View {
    @Binding var name: String
    let selectedColor: HabitColor
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // Modern Name Input
        VStack(alignment: .leading) {
            TextField("Habit Title", text: $name)
                .font(.title3).bold()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
                )
                .textFieldStyle(PlainTextFieldStyle())
        }
    }
}

struct ColorSelectionSection: View {
    @Binding var selectedColor: HabitColor
    @Binding var selectedCustomColor: Color
    @State private var customHue: Double = 0.58
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(HabitColor.allCases, id: \.self) { color in
                    ColorSelectionCircle(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        selectedColor = color
                    }
                }
            }

            if selectedColor == .custom {
                CustomRainbowSlider(hue: $customHue) { color in
                    selectedCustomColor = color
                }
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .onAppear {
            if let hex = selectedCustomColor.hexString {
                customHue = hue(from: hex) ?? customHue
            }
        }
        .onChange(of: selectedColor) {
            if selectedColor == .custom {
                selectedCustomColor = colorForHue(customHue)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedColor == .custom)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
        )
    }

    private func colorForHue(_ hue: Double) -> Color {
        Color(hue: hue, saturation: 0.9, brightness: 0.95)
    }

    private func hue(from hex: String) -> Double? {
        guard let color = Color(hex: hex) else { return nil }
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return nil }
        return Double(hue)
    }
}

struct ColorSelectionCircle: View {
    let color: HabitColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color == .custom ? AnyShapeStyle(
                        AngularGradient(
                            gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red]),
                            center: .center
                        )
                    ) : AnyShapeStyle(color.color))
                    .frame(width: 430, height: 40)
                
                if isSelected {
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "checkmark")
                        .font(.body).bold()
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(color == .custom ? "Custom color" : color.rawValue)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct CustomRainbowSlider: View {
    @Binding var hue: Double
    let onColorChanged: (Color) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let thumbSize: CGFloat = 30
                let usableWidth = max(width - thumbSize, 1)
                let xPosition = CGFloat(hue) * usableWidth

                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())
                    .frame(height: 18)

                    Circle()
                        .fill(Color(hue: hue, saturation: 0.9, brightness: 0.95))
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                        .offset(x: xPosition)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let clamped = min(max(value.location.x - (thumbSize / 2), 0), usableWidth)
                            hue = Double(clamped / usableWidth)
                            onColorChanged(Color(hue: hue, saturation: 0.9, brightness: 0.95))
                        }
                )
            }
            .frame(height: 34)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Custom color slider")
            .accessibilityValue("Hue \(Int(hue * 360)) degrees")
        }
    }
}

struct EditHabitView: View {
    let habit: Habit
    @Environment(HabitStore.self) private var habitStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var name: String
    @State private var selectedColor: HabitColor
    @State private var selectedCustomColor: Color
    @State private var colorWaveTrigger: Int = 0
    @State private var usesTargetGoal: Bool
    @State private var target: Int
    @State private var remindersEnabled: Bool
    @State private var reminderTime: Date
    @State private var selectedReminderWeekdays: Set<Int>
    @State private var showingDeleteAlert = false
    
    init(habit: Habit) {
        self.habit = habit
        _name = State(initialValue: habit.name)
        _selectedColor = State(initialValue: habit.color)
        _selectedCustomColor = State(initialValue: habit.displayColor)
        _usesTargetGoal = State(initialValue: habit.usesTargetGoal)
        _target = State(initialValue: max(1, habit.target))
        let weekdays = Set(habit.reminderWeekdays ?? [])
        _selectedReminderWeekdays = State(initialValue: weekdays)

        if let components = habit.reminderTime,
           let date = Calendar.current.date(from: components) {
            _reminderTime = State(initialValue: date)
        } else {
            _reminderTime = State(initialValue: Date())
        }
        _remindersEnabled = State(initialValue: !weekdays.isEmpty && habit.reminderTime != nil)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                (colorScheme == .light ? Color.secondary.opacity(0.2) : Color.black)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Progress Preview Card
                        ProgressPreviewCard(
                            habit: previewHabit,
                            selectedColor: selectedColorValue,
                            externalWaveTrigger: colorWaveTrigger
                        )
                        
                        // Habit Name Input Section
                        HabitNameSection(name: $name, selectedColor: selectedColor)
                        
                        // Color Selection
                        ColorSelectionSection(
                            selectedColor: $selectedColor,
                            selectedCustomColor: $selectedCustomColor
                        )

                        TargetUnitSection(
                            usesTargetGoal: $usesTargetGoal,
                            target: $target
                        )

                        ReminderSection(
                            remindersEnabled: $remindersEnabled,
                            reminderTime: $reminderTime,
                            selectedWeekdays: $selectedReminderWeekdays,
                            selectedColor: selectedColorValue
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .onChange(of: selectedColor) {
                colorWaveTrigger += 1
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .tint(.orange)
                            .font(.headline.weight(.semibold))
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveChanges()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .font(.headline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(selectedColorValue)
                    .opacity(name.isEmpty ? 0.45 : 1.0)
                    .disabled(name.isEmpty)
                    .id(selectedColor.rawValue + (selectedCustomColor.hexString ?? ""))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
            }
            .alert("Delete Habit", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteHabit()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete '\(habit.name)'? This action cannot be undone.")
            }
        }
    }
    
    private var previewHabit: Habit {
        var preview = habit
        preview.name = name
        preview.color = selectedColor
        preview.usesTargetGoal = usesTargetGoal
        preview.target = target
        preview.unit = "Count"
        preview.customColorHex = selectedColor == .custom ? selectedCustomColor.hexString : nil
        return preview
    }
    
    private func saveChanges() {
        var updatedHabit = habit
        updatedHabit.name = name
        updatedHabit.color = selectedColor
        updatedHabit.usesTargetGoal = usesTargetGoal
        updatedHabit.target = target
        updatedHabit.unit = "Count"
        updatedHabit.customColorHex = selectedColor == .custom ? selectedCustomColor.hexString : nil
        updatedHabit.reminderTime = remindersEnabled ? Calendar.current.dateComponents([.hour, .minute], from: reminderTime) : nil
        updatedHabit.reminderWeekdays = remindersEnabled ? selectedReminderWeekdays.sorted() : nil
        
        habitStore.updateHabit(updatedHabit)
        dismiss()
    }
    
    private func deleteHabit() {
        habitStore.deleteHabit(habit)
        dismiss()
    }

    private var selectedColorValue: Color {
        selectedColor == .custom ? selectedCustomColor : selectedColor.color
    }
}

struct TargetUnitSection: View {
    @Binding var usesTargetGoal: Bool
    @Binding var target: Int
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isTargetFocused: Bool
    @State private var targetText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $usesTargetGoal) {
                Label("Goals", systemImage: "target")
            }
                .font(.headline)
                .onChange(of: usesTargetGoal) {
                    HapticManager.shared.selectionChanged()
                }
                .accessibilityLabel("Goals")

            if usesTargetGoal {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Daily target")
                            .font(.headline)
                        Spacer()
                        TextField("1", text: $targetText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.headline.monospacedDigit())
                            .frame(width: 90)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.14))
                            )
                            .focused($isTargetFocused)
                            .onChange(of: targetText) {
                                let filtered = targetText.filter(\.isNumber)
                                if filtered != targetText {
                                    targetText = filtered
                                }

                                guard let parsed = Int(filtered) else { return }
                                let clamped = min(9999, max(1, parsed))
                                target = clamped
                                if "\(clamped)" != filtered {
                                    targetText = "\(clamped)"
                                }
                            }
                    }

                }
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .onAppear {
            targetText = "\(min(9999, max(1, target)))"
        }
        .onChange(of: target) {
            let normalized = "\(min(9999, max(1, target)))"
            if !isTargetFocused || targetText.isEmpty {
                targetText = normalized
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: usesTargetGoal)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
        )
    }
}

struct ReminderSection: View {
    @Binding var remindersEnabled: Bool
    @Binding var reminderTime: Date
    @Binding var selectedWeekdays: Set<Int>
    let selectedColor: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var notificationDenied = false

    private var orderedWeekdays: [(index: Int, symbol: String)] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let start = max(0, min(6, calendar.firstWeekday - 1))
        let reordered = Array(symbols[start...] + symbols[..<start])
        return reordered.enumerated().map { offset, symbol in
            let weekday = ((start + offset) % 7) + 1
            return (weekday, symbol)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $remindersEnabled) {
                Label("Reminder", systemImage: "bell")
            }
                .font(.headline)
                .accessibilityLabel("Enable habit reminder")
                .onChange(of: remindersEnabled) {
                    HapticManager.shared.selectionChanged()
                    if remindersEnabled {
                        Task {
                            let isAuthorized = await ensureNotificationAuthorization()
                            await MainActor.run {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    notificationDenied = !isAuthorized
                                    if !isAuthorized {
                                        remindersEnabled = false
                                        return
                                    }

                                    if selectedWeekdays.isEmpty {
                                        selectedWeekdays = [Calendar.current.component(.weekday, from: Date())]
                                    }
                                }
                            }
                        }
                    }
                }

            if notificationDenied {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notifications are off for Mini Habit Tracker.")
                            .font(.subheadline.weight(.semibold))
                        Button("Open Settings") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.12))
                )
                .transition(.opacity)
            }

            if remindersEnabled {
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .accessibilityLabel("Reminder time")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(orderedWeekdays, id: \.index) { day in
                        Button {
                            HapticManager.shared.selectionChanged()
                            if selectedWeekdays.contains(day.index) {
                                selectedWeekdays.remove(day.index)
                            } else {
                                selectedWeekdays.insert(day.index)
                            }
                        } label: {
                            Text(day.symbol)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedWeekdays.contains(day.index) ? selectedColor.opacity(0.25) : Color.secondary.opacity(0.15))
                                )
                        }
                        .foregroundStyle(selectedWeekdays.contains(day.index) ? .primary : .secondary)
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.symbol)
                        .accessibilityValue(selectedWeekdays.contains(day.index) ? "Selected" : "Not selected")
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: remindersEnabled)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
        )
    }

    private func ensureNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}

#Preview {
    let store = HabitStore()
    let habit = Habit(
        name: "Read",
        frequency: .daily,
        usesTargetGoal: true,
        target: 2,
        unit: "Sessions",
        color: .blue
    )
    store.habits = [habit]
    store.completions = [
        HabitCompletion(habitId: habit.id, date: Date(), value: 1),
        HabitCompletion(habitId: habit.id, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, value: 2)
    ]

    return NavigationStack {
        EditHabitView(habit: habit)
            .environment(store)
    }
}
