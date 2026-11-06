//
//  NotificationManager.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/18/25.
//

import SwiftUI
import UserNotifications
import UIKit
import CloudKit

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let container = CKContainer.default()

    private override init() {
        super.init()
    }

    // MARK: - Configure

    /// Call once after sign-in / app launch
    func configure() {
        center.delegate = self

        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("🔔 Notification permission error:", error)
                return
            }

            print("🔔 Notifications granted:", granted)

            guard granted else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - APNs Registration Logging

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("✅ APNs device token:", tokenString)
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ Failed to register for remote notifications:", error)
    }

    // MARK: - CloudKit Subscription Setup

    /// Creates/updates a subscription for the currently signed-in user's notification records.
    ///
    /// Call this once after you know the user's profile ID.
    /// Example:
    /// await NotificationManager.shared.ensureCloudKitNotificationSubscription(forUserId: store.profile.id.uuidString)
    func ensureCloudKitNotificationSubscription(forUserId userId: String) async {
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserId.isEmpty else {
            print("⚠️ Cannot create notification subscription: empty user id")
            return
        }

        let subscriptionID = "user-notifications-\(trimmedUserId)"

        let predicate = NSPredicate(format: "recipientUserId == %@", trimmedUserId)

        let subscription = CKQuerySubscription(
            recordType: "AppNotification",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true

        // These keys are copied into the push payload
        info.titleLocalizationKey = "%1$@"
        info.titleLocalizationArgs = ["title"]

        info.alertLocalizationKey = "%1$@"
        info.alertLocalizationArgs = ["body"]

        info.soundName = "default"
        info.shouldBadge = true

        subscription.notificationInfo = info

        do {
            let saved = try await container.publicCloudDatabase.save(subscription)
            print("✅ Saved CloudKit notification subscription:", saved.subscriptionID)
        } catch {
            // "already exists" can happen and is usually fine depending on your flow
            print("❌ Failed to save CloudKit subscription:", error)
        }
    }

    // MARK: - Remote Notification Handling

    /// Call this from AppDelegate when a remote notification arrives.
    ///
    /// Returns `.newData` if it looks like a CloudKit notification.
    func handleRemoteNotification(
        userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            print("ℹ️ Remote notification received, but not a CloudKit notification")
            completionHandler(.noData)
            return
        }

        print("📬 CloudKit remote notification received")
        print("   notificationID:", ckNotification.notificationID?.description ?? "nil")

        if let queryNotification = ckNotification as? CKQueryNotification {
            print("   recordID:", queryNotification.recordID?.recordName ?? "nil")
            print("   subscriptionID:", queryNotification.subscriptionID ?? "nil")
        }

        completionHandler(.newData)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners while app is open
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📬 willPresent notification:", notification.request.identifier)
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle tap on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("📬 didReceive notification:", response.notification.request.identifier)

        let userInfo = response.notification.request.content.userInfo
        if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo),
           let queryNotification = ckNotification as? CKQueryNotification {
            print("📍 User tapped CloudKit notification for record:", queryNotification.recordID?.recordName ?? "nil")
        }

        completionHandler()
    }

    // MARK: - Test Helper

    func scheduleTestLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Prayer Notification"
        content.body = "This is how it will look when someone interacts with your prayer."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(
            identifier: "test_local_notification",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test notification:", error)
            } else {
                print("✅ Test notification scheduled in 5 seconds")
            }
        }
    }

    // MARK: - Daily Declarations

    private struct DailyDeclarationItem: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let text: String
        let scriptureReference: String?
    }

    private let dailyDeclarations: [DailyDeclarationItem] = [
        DailyDeclarationItem(
            title: "I Am Loved",
            text: "Today I stand in the truth that I am fully known and fully loved by God. Nothing can separate me from His love.",
            scriptureReference: "Romans 8:38–39"
        ),
        DailyDeclarationItem(
            title: "Peace Over Anxiety",
            text: "Today I choose peace. My mind is steady because my trust is in God, not in my circumstances.",
            scriptureReference: "Isaiah 26:3"
        ),
        DailyDeclarationItem(
            title: "Strength for Today",
            text: "I am strong and courageous. God is with me, goes before me, and will not fail me.",
            scriptureReference: "Joshua 1:9"
        ),
        DailyDeclarationItem(
            title: "Purpose & Calling",
            text: "My life has purpose. I am called, equipped, and anointed to walk in the good works God prepared for me.",
            scriptureReference: "Ephesians 2:10"
        ),
        DailyDeclarationItem(
            title: "Joy in Every Season",
            text: "The joy of the Lord is my strength. I will not be defined by what I feel, but by what God says.",
            scriptureReference: "Nehemiah 8:10"
        ),
        DailyDeclarationItem(
            title: "Victory in Christ",
            text: "I am more than a conqueror through Christ. Every battle I face today, I face from a place of victory.",
            scriptureReference: "Romans 8:37"
        ),
        DailyDeclarationItem(
            title: "Guarded Heart",
            text: "The peace of God guards my heart and mind. Fear, worry, and shame have no permanent place in me.",
            scriptureReference: "Philippians 4:7"
        )
    ]

    func scheduleDailyDeclarationNotification(hour: Int = 7, minute: Int = 0) {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_declaration_notification"])

        let declaration = declarationForToday()

        let content = UNMutableNotificationContent()
        content.title = "Daily Declaration – \(declaration.title)"
        content.body = shortBody(from: declaration)
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily_declaration_notification",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule daily declaration:", error)
            } else {
                print("✅ Daily declaration scheduled at \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    func cancelDailyDeclarationNotification() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_declaration_notification"])
    }

    // MARK: - Helpers

    private func declarationForToday() -> DailyDeclarationItem {
        guard !dailyDeclarations.isEmpty else {
            return DailyDeclarationItem(
                title: "Daily Declaration",
                text: "Today I speak life, faith, and hope over my day.",
                scriptureReference: nil
            )
        }

        let dayNumber = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let index = dayNumber % dailyDeclarations.count
        return dailyDeclarations[index]
    }

    private func shortBody(from declaration: DailyDeclarationItem) -> String {
        var base = declaration.text
        if base.count > 180 {
            let idx = base.index(base.startIndex, offsetBy: 180)
            base = String(base[..<idx]) + "…"
        }

        if let ref = declaration.scriptureReference, !ref.isEmpty {
            return base + " (\(ref))"
        } else {
            return base
        }
    }
}
