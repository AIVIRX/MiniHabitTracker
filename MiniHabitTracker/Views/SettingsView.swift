import SwiftUI
import RevenueCatUI

struct SettingsView: View {
    @Environment(HabitStore.self) private var habitStore
    @EnvironmentObject private var store: Store
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @Environment(\.requestReview) var requestReview
    @Environment(\.colorScheme) var colorScheme
    @State private var showingResetAlert = false
    @State private var showingPaywall = false
    private let privacyPolicyURL = URL(string: "https://aivirx.com/minihabits/privacy-policy")
    private let termsOfServiceURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    private let supportEmailURL = URL(string: "mailto:support@aivirx.com")
    private let otherAppURL = URL(string: "https://apps.apple.com/us/app/task-now-simple-to-do-list/id1639588217")
    
    enum AppTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
        
        var icon: String {
            switch self {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .system: return "gear"
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack{
                (colorScheme == .light ? Color.secondary.opacity(0.2) : Color.black)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        premiumCard
                        sectionTitle("Utilities")
                        settingsGroup {
                            themeDropdownRow(showsDivider: true)
                            actionRow(
                                icon: "trash.fill",
                                title: "Reset All Data",
                                iconColor: .red,
                                showsDivider: false,
                                tint: .red,
                                action: { showingResetAlert = true }
                            )
                        }
                        
                        sectionTitle("Support and Feedback")
                        settingsGroup {
                            if let otherAppURL {
                                actionRow(
                                    icon: "square.grid.2x2.fill",
                                    iconAssetName: "tasknow",
                                    title: "Task Now - Simple Todo List",
                                    iconColor: .blue,
                                    showsDivider: true,
                                    trailingIcon: "arrow.up.right",
                                    action: { UIApplication.shared.open(otherAppURL) }
                                )
                            }
                            actionRow(
                                icon: "envelope.fill",
                                title: "Contact Support",
                                iconColor: .blue,
                                showsDivider: true,
                                trailingIcon: "arrow.up.right",
                                action: {
                                    if let supportEmailURL {
                                        UIApplication.shared.open(supportEmailURL)
                                    }
                                }
                            )
                            actionRow(
                                icon: "star.fill",
                                title: "Rate MiniHabits",
                                iconColor: .yellow,
                                showsDivider: false,
                                trailingIcon: "arrow.up.right",
                                action: { requestReview() }
                            )
                        }
                        
                        sectionTitle("Legal")
                        settingsGroup {
                            if let privacyPolicyURL {
                                actionRow(
                                    icon: "hand.raised.fill",
                                    title: "Privacy Policy",
                                    iconColor: .indigo,
                                    showsDivider: termsOfServiceURL != nil,
                                    trailingIcon: "arrow.up.right",
                                    action: { UIApplication.shared.open(privacyPolicyURL) }
                                )
                            }
                            if let termsOfServiceURL {
                                actionRow(
                                    icon: "doc.text.fill",
                                    title: "Terms of Service",
                                    iconColor: .teal,
                                    showsDivider: false,
                                    trailingIcon: "arrow.up.right",
                                    action: { UIApplication.shared.open(termsOfServiceURL) }
                                )
                            }
                        }
                        Text("Version \(appVersion)")
                            .foregroundStyle(.secondary)
                        
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .alert("Reset All Data", isPresented: $showingResetAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        performReset()
                    }
                } message: {
                    Text("This will permanently delete all your habits, completions, and achievements. This action cannot be undone.")
                }
                .sheet(isPresented: $showingPaywall) {
                    PaywallView(displayCloseButton: true)
                }
                .onChange(of: showingPaywall) { _, isPresented in
                    if !isPresented {
                        store.loadStoredPurchases()
                    }
                }
                .onAppear {
                    store.loadStoredPurchases()
                }
            }
        }
    }

    private var premiumCard: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: store.isPremiumActive ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.body)
                    .foregroundStyle(store.isPremiumActive ? .green : .red)
                Text("MiniHabits Pro")
                    .font(.title3).bold()
                    .foregroundStyle(.white)
                Spacer()
                Text("View Plans")
                    .font(.body).bold()
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.22))
                            .overlay(Capsule().stroke(Color.white.opacity(0.32), lineWidth: 1))
                    )
            }
            .padding(.horizontal, 20)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.20, blue: 0.95),
                                Color(red: 0.30, green: 0.08, blue: 0.85),
                                Color(red: 0.55, green: 0.12, blue: 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.20), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.horizontal, 4)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .light ? Color.white : Color.gray.opacity(0.25))
        )
    }

    private func actionRow(
        icon: String,
        iconAssetName: String? = nil,
        title: String,
        iconColor: Color = .blue,
        showsDivider: Bool = false,
        trailingIcon: String = "chevron.right",
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let iconAssetName {
                    rowImageIcon(iconAssetName)
                } else {
                    rowIcon(icon, color: iconColor)
                }
                Text(title)
                    .font(.body).fontWeight(.medium)
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: trailingIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.36))
            }
            .frame(height: 60)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .background(Color.primary.opacity(0.14))
                    .padding(.leading, 72)
            }
        }
    }

    private func rowIcon(_ systemName: String, color: Color = .blue) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color.opacity(0.2))
            .frame(width: 35, height: 35)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 17))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
            )
    }

    private func rowImageIcon(_ assetName: String) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.08))
            .frame(width: 35, height: 35)
            .overlay(
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 35, height: 35)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
    }

    private func themeDropdownRow(showsDivider: Bool) -> some View {
        HStack(spacing: 14) {
            rowIcon("circle.grid.2x2.fill", color: .purple)
            Text("Theme")
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        appTheme = theme
                    } label: {
                        if appTheme == theme {
                            Label(theme.rawValue, systemImage: "checkmark")
                        } else {
                            Text(theme.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(appTheme.rawValue)
                        .font(.body)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.body)
                }
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 18)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .background(Color.primary.opacity(0.14))
                    .padding(.leading, 72)
            }
        }
    }

    private func performReset() {
        habitStore.habits.removeAll()
        habitStore.completions.removeAll()
        habitStore.saveData()
        AchievementManager.shared.unlockedAchievements.removeAll()
    }
}

#Preview {
    SettingsView()
        .environment(HabitStore())
}
