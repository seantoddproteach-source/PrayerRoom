//
//  PrayerWallApp.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/13/25.
//

import SwiftUI
import OneSignalFramework
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationManager.shared.handleRemoteNotification(
            userInfo: userInfo,
            fetchCompletionHandler: completionHandler
        )
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        OneSignal.Debug.setLogLevel(.LL_VERBOSE)

        // Replace this with your real OneSignal App ID
        OneSignal.initialize("374ed5ec-f100-4ddd-8a7c-e6f66267d391", withLaunchOptions: launchOptions)

        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")
        }, fallbackToSettings: false)

        return true
    }
}

@main
struct PrayerWallApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var store = PrayerStore()
    @StateObject private var authManager = AppleSignInManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    RootView1()
                        .onAppear {
                            NotificationManager.shared.configure()

                        }
                } else {
                    SignInView()
                }
            }
            .environmentObject(store)
            .environmentObject(authManager)
            .task {
                authManager.restoreSignInState()
            }
        }
    }
}
