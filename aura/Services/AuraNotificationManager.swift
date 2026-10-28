import SwiftUI
import UserNotifications
import Combine

// ============================================================
// MARK: - NOTIFICATION MANAGER (Smart Reminders)
// ============================================================

/// Handles local push notifications for the two daily mood
/// check-in reminders (09:00 morning, 18:00 evening).
///
/// Usage:
///   • Call `AuraNotificationManager.shared.enableReminders()`
///     when the user activates Premium.
///   • Call `AuraNotificationManager.shared.disableReminders()`
///     to cancel them.
///
/// The manager requests permission on the first call to
/// `enableReminders()` and gracefully no-ops if the user
/// denies the alert.
final class AuraNotificationManager: ObservableObject {

    static let shared = AuraNotificationManager()

    @Published var isAuthorized: Bool = false

    private let center = UNUserNotificationCenter.current()
    private let morningID = "aura.reminder.morning"
    private let eveningID = "aura.reminder.evening"

    private init() {
        refreshAuthStatus()
    }

    // MARK: - Public API

    /// Requests permission (if needed) and schedules the two
    /// daily repeating notifications.
    func enableReminders() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted { self?.scheduleDaily() }
            }
        }
    }

    /// Removes both pending reminders.
    func disableReminders() {
        center.removePendingNotificationRequests(
            withIdentifiers: [morningID, eveningID]
        )
    }

    /// Re-checks the current authorisation status (useful on
    /// appear so the UI can react if the user toggled
    /// permissions in Settings).
    func refreshAuthStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Private

    private func scheduleDaily() {
        // Remove old ones first to avoid duplicates.
        disableReminders()

        scheduleSingle(
            id: morningID,
            hour: 9, minute: 0,
            title: "Good morning ☀️",
            body: "How are you feeling? Log your morning mood."
        )

        scheduleSingle(
            id: eveningID,
            hour: 18, minute: 0,
            title: "Evening check-in 🌙",
            body: "Take a moment — how was your day?"
        )
    }

    private func scheduleSingle(id: String, hour: Int, minute: Int,
                                title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        var date = DateComponents()
        date.hour   = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: date, repeats: true
        )

        let request = UNNotificationRequest(
            identifier: id, content: content, trigger: trigger
        )

        center.add(request) { error in
            if let error { print("Aura notification error: \(error)") }
        }
    }
}
