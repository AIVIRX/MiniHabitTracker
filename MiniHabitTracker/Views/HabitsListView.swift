import SwiftUI
import RevenueCatUI

struct HabitsListView: View {
    @Environment(HabitStore.self) private var habitStore
    @EnvironmentObject private var store: Store
    @State private var showingAddHabit = false
    @State private var showingPaywall = false
    @State private var searchText = ""
    private let freeHabitLimit = 2

    @State private var viewMode: ViewMode = .list
    @State private var sortOption: SortOption = .manual
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case grid = "Grid"
        case compact = "Compact"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            case .compact: return "rectangle.compress.vertical"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case manual = "Manual"
        case name = "Name"
        case streak = "Streak"
        case created = "Created"
        
        var icon: String {
            switch self {
            case .manual: return "hand.draw"
            case .name: return "textformat"
            case .streak: return "flame"
            case .created: return "calendar"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filters
                SearchAndFilterView(
                    searchText: $searchText,
                    viewMode: $viewMode,
                    sortOption: $sortOption
                )
                
                // Habits content
                if filteredHabits.isEmpty {
                    EmptyStateView(
                        icon: "plus.circle",
                        title: "No Habits Found",
                        subtitle: searchText.isEmpty ? "Add your first habit to get started" : "Try adjusting your search or filters"
                    )
                } else {
                    List {
                        ForEach(filteredHabits) { habit in
                            HabitRowView(habit: habit)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onMove(perform: canReorder ? moveHabits : nil)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(HabitsListView.SortOption.allCases, id: \.self) { option in
                            Button(action: { sortOption = option }) {
                                Label(option.rawValue, systemImage: option.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.body.weight(.semibold))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if canCreateHabit {
                            showingAddHabit = true
                        } else {
                            showingPaywall = true
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
                    .environment(habitStore)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(displayCloseButton: true)
            }
        }
    }
    
    private var filteredHabits: [Habit] {
        var habits = habitStore.habits
        
        // Filter by search text
        if !searchText.isEmpty {
            habits = habits.filter { habit in
                habit.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort habits
        if sortOption != .manual {
            habits.sort { first, second in
                switch sortOption {
                case .manual:
                    return false
                case .name:
                    return first.name < second.name
                case .streak:
                    return first.streak > second.streak
                case .created:
                    return first.createdAt > second.createdAt
                }
            }
        }
        
        return habits
    }

    private var canReorder: Bool {
        sortOption == .manual && searchText.isEmpty
    }

    private var canCreateHabit: Bool {
        store.isPremiumActive || habitStore.habits.count < freeHabitLimit
    }

    private func moveHabits(from source: IndexSet, to destination: Int) {
        habitStore.moveHabits(fromOffsets: source, toOffset: destination)
    }
}

struct SearchAndFilterView: View {
    @Binding var searchText: String
    @Binding var viewMode: HabitsListView.ViewMode
    @Binding var sortOption: HabitsListView.SortOption
    @State private var showingFilters = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search habits...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal)
            

            
            // View mode and sort options
            HStack {
                // View mode picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(HabitsListView.ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120)
                
                Spacer()
                
                // Sort button
                Menu {
                    ForEach(HabitsListView.SortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            Label(option.rawValue, systemImage: option.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOption.rawValue)
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? color : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HabitRowView: View {
    let habit: Habit
    @Environment(HabitStore.self) private var habitStore
    @State private var showingDetail = false
    
    var body: some View {
        HabitCard(
            habit: habit,
            isCompleted: habitStore.isCompleted(for: habit.id, on: Date()),
            onToggle: {
                if habitStore.isCompleted(for: habit.id, on: Date()) {
                    let completions = habitStore.getCompletions(for: habit.id, on: Date())
                    if let completion = completions.first {
                        habitStore.removeCompletion(completion)
                    }
                } else {
                    habitStore.addCompletion(for: habit.id)
                }
            },
            onTap: {
                showingDetail = true
            }
        )
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                HabitDetailView(habit: habit)
                    .environment(habitStore)
            }
        }
    }
}
