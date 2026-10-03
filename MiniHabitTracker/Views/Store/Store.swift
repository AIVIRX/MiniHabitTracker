//
//  Store.swift
//  MiniHabitTracker
//
//  RevenueCat-backed store manager.
//

import Foundation
import RevenueCat

@MainActor
final class Store: ObservableObject {
    @Published private(set) var isPremiumActive = false
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?

    private let premiumEntitlementID = "premium"
    private let premiumStatusKey = "PremiumStatusActive"
    private let appGroupIdentifier = "group.com.Maicol.MiniHabitTracker"

    init() {
        Task {
            await refreshEntitlements()
        }
    }

    func loadStoredPurchases() {
        Task {
            await refreshEntitlements()
        }
    }

    func refreshEntitlements() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPremiumActive = customerInfo.entitlements.all[premiumEntitlementID]?.isActive == true
            persistPremiumStatus()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPremiumActive = customerInfo.entitlements.all[premiumEntitlementID]?.isActive == true
            persistPremiumStatus()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func persistPremiumStatus() {
        UserDefaults.standard.set(isPremiumActive, forKey: premiumStatusKey)
        UserDefaults(suiteName: appGroupIdentifier)?.set(isPremiumActive, forKey: premiumStatusKey)
    }
}
