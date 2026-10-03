//
//  MiniHabitTrackerApp.swift
//  MiniHabitTracker
//
//  Created by Maicol Cabreja on 7/29/25.
//

import SwiftUI
import RevenueCat

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            
        return true
    }
}

@main
struct MiniHabitTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()
    @State private var habitStore = HabitStore()
    @StateObject private var achievementManager = AchievementManager.shared
    @AppStorage("appTheme") private var appTheme: SettingsView.AppTheme = .system

    init() {
        Purchases.configure(withAPIKey: "appl_mIaLBiQAKkDTFiOwEPmyNYWCSWa")
    }

    var body: some Scene {
        WindowGroup {
            VStack{
                MainTabView()
                    .environmentObject(store)
                      .environment(habitStore)
                    .environmentObject(achievementManager)
                    .preferredColorScheme(colorScheme)
            }
            .onAppear {
                achievementManager.checkAchievements(habitStore: habitStore)
                HapticManager.shared.prepare()
                store.loadStoredPurchases()
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}
