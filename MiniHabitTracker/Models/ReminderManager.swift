import Foundation
import UserNotifications

struct ReminderManager {
    static let shared = ReminderManager()

    private init() {}

    func syncReminder(for habit: Habit) {
        Task {
            await removeReminders(for: habit.id)

            guard
                let time = habit.reminderTime,
                let weekdays = habit.reminderWeekdays,
                !weekdays.isEmpty
            else {
                return
            }

            let center = UNUserNotificationCenter.current()
            let granted = await requestAuthorizationIfNeeded(center: center)
            guard granted else { return }

            for weekday in Set(weekdays).sorted() {
                var components = DateComponents()
                components.weekday = weekday
                components.hour = time.hour
                components.minute = time.minute

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let content = UNMutableNotificationContent()
                content.title = habit.name
                content.body = "Time to check in for your habit."
                content.sound = .default

                let id = reminderIdentifier(habitId: habit.id, weekday: weekday)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

                do {
                    try await center.add(request)
                } catch {
                    print("Failed to schedule reminder for \(habit.id): \(error)")
                }
            }
        }
    }

    func removeReminders(for habitId: UUID) async {
        let ids = (1...7).map { reminderIdentifier(habitId: habitId, weekday: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func requestAuthorizationIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                print("Notification authorization failed: \(error)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func reminderIdentifier(habitId: UUID, weekday: Int) -> String {
        "habit-reminder-\(habitId.uuidString)-\(weekday)"
    }
}
