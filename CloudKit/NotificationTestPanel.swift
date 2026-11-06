//
//  NotificationTestPanel.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/18/25.
//

import SwiftUI

/// A small debug-only panel with a button
/// to trigger a local test notification.
///
/// Add `NotificationTestPanel()` inside any screen
/// (e.g., ProfileView) while you're developing.
struct NotificationTestPanel: View {
    var body: some View {
        #if DEBUG
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)
            
            Text("Developer Tools")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button {
                NotificationManager.shared.scheduleTestLocalNotification()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                    Text("Send Test Notification")
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
            
            Text("Runs a local test in 5 seconds so you can verify banners, sounds, and behavior.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding()
        #else
        EmptyView()
        #endif
    }
}
