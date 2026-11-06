//
//  SettingsView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/15/25.
//

import SwiftUI
import UIKit

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var store: PrayerStore
    @EnvironmentObject var authManager: AppleSignInManager
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("prayerRoom_notificationsEnabled") private var notificationsEnabled: Bool = true
    
    // 🔔 Daily Declarations prefs
    @AppStorage("dailyDeclarationEnabled") private var dailyDeclarationEnabled: Bool = false
    @AppStorage("dailyDeclarationHour") private var dailyDeclarationHour: Int = 7
    @AppStorage("dailyDeclarationMinute") private var dailyDeclarationMinute: Int = 0
    
    // Local Date binding for the time picker
    @State private var dailyDeclarationTime: Date = {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(
            bySettingHour: 7,
            minute: 0,
            second: 0,
            of: now
        ) ?? now
    }()
    
    // 🧨 Delete account alert
    @State private var showingDeleteAlert: Bool = false
    
    var body: some View {
        ZStack {
            PrayerTheme.gradient
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                // 👇 Top bar, same pattern as TestimonyFeedView
                HStack {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Scrollable content under the pinned header
                ScrollView {
                    VStack(spacing: 18) {
                        // MARK: - Header / account card
                        accountHeaderCard
                            .padding(.horizontal)
                        
                        // MARK: - Notifications card (includes Daily Declarations)
                        notificationsCard
                            .padding(.horizontal)
                        
                        // MARK: - Community & Support
                        communityCard
                            .padding(.horizontal)
                        
                        supportCard
                            .padding(.horizontal)
                        
                        // MARK: - Sign Out + Delete Account
                        signOutCard
                            .padding(.horizontal)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
        }
        // When Settings opens, sync the time from stored hour/minute
        .onAppear {
            loadSavedDailyTime()
        }
        // If user toggles daily declarations on/off, reschedule
        .onChange(of: dailyDeclarationEnabled) { _ in
            updateDailyDeclarationSchedule()
        }
        // If user changes the time, reschedule
        .onChange(of: dailyDeclarationTime) { _ in
            if dailyDeclarationEnabled {
                updateDailyDeclarationSchedule()
            }
        }
        // 🔴 Delete account confirmation
        .alert("Delete account?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            
            Button("Delete Account", role: .destructive) {
                // TODO: Replace this with your real account deletion logic.
                // e.g. await store.deleteCurrentUserFromCloudKit()
                // For now, just sign out and dismiss.
                authManager.signOut()
                dismiss()
            }
        } message: {
            Text("This will permanently remove your account and data from the Prayer Room experience. This action cannot be undone.")
        }
    }
    
    // MARK: - Cards
    
    private var accountHeaderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                // Avatar
                Group {
                    if let data = store.profile.profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [PrayerTheme.accent, PrayerTheme.highlight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(initials(from: store.profile.displayName.isEmpty ? "New User" : store.profile.displayName))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 56, height: 56)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.profile.displayName.isEmpty ? "New User" : store.profile.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text(store.profile.username.isEmpty ? "@username" : store.profile.username)
                        .font(.system(size: 13))
                        .foregroundColor(PrayerTheme.textSecondary)
                    
                    if !store.profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(store.profile.bio)
                            .font(.system(size: 12))
                            .foregroundColor(PrayerTheme.textPrimary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            NavigationLink {
                EditProfileView()
                    .environmentObject(store)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Edit Profile")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
                .cornerRadius(999)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Notifications", icon: "bell.badge.fill")
            
            // General app notifications toggle
            HStack(spacing: 12) {
                SettingsIconCircle(systemName: "hands.sparkles.fill", color: .blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prayer reminders")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(PrayerTheme.textPrimary)
                    Text("Get nudges to pray, share updates, or post testimonies.")
                        .font(.system(size: 12))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
                    .tint(PrayerTheme.accent)
            }
            .frame(minHeight: 44)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // 🔔 Daily Declarations controls
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    SettingsIconCircle(systemName: "sun.and.horizon.fill", color: .orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Declarations")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PrayerTheme.textPrimary)
                        Text("Receive a short faith-filled declaration once a day.")
                            .font(.system(size: 12))
                            .foregroundColor(PrayerTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $dailyDeclarationEnabled)
                        .labelsHidden()
                        .tint(PrayerTheme.accent)
                }
                .frame(minHeight: 44)
                
                if dailyDeclarationEnabled {
                    HStack {
                        DatePicker(
                            "Notification time",
                            selection: $dailyDeclarationTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        
                        Spacer()
                    }
                    
                    Text("We’ll send your Daily Declaration around this time each day.")
                        .font(.system(size: 11))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var communityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Community", icon: "person.3.fill")
            
            // 👉 Instructions
            NavigationLink {
                HowPrayerRoomWorksView()
            } label: {
                HStack(spacing: 12) {
                    SettingsIconCircle(systemName: "sparkles", color: .purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How Prayer Room Works")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PrayerTheme.textPrimary)
                        Text("Walk through Prayer Wall, Testimonies, Threads, Badges, and Proclaim Meter.")
                            .font(.system(size: 12))
                            .foregroundColor(PrayerTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            
            NavigationLink {
                CommunityGuidelinesView()
            } label: {
                HStack(spacing: 12) {
                    SettingsIconCircle(systemName: "hand.raised.fill", color: .orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Community Guidelines")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PrayerTheme.textPrimary)
                        Text("How we keep this a safe, honoring space for prayer.")
                            .font(.system(size: 12))
                            .foregroundColor(PrayerTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Support", icon: "questionmark.circle.fill")
            
            Button {
                openSupportEmail()
            } label: {
                HStack(spacing: 12) {
                    SettingsIconCircle(systemName: "envelope.fill", color: .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contact Support")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PrayerTheme.textPrimary)
                        Text("support@prayerroom.app")
                            .font(.system(size: 12))
                            .foregroundColor(PrayerTheme.textSecondary)
                    }
                    
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    // 🔴 SIGN OUT + DELETE ACCOUNT CARD
    private var signOutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Account", icon: "person.crop.circle.fill")
            
            Button(role: .destructive) {
                authManager.signOut()
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.10))
                .cornerRadius(999)
            }
            .buttonStyle(.plain)
            
            // 🧨 Delete Account Button
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Delete Account")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.18))
                .foregroundColor(.red.opacity(0.95))
                .cornerRadius(999)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private func initials(from name: String) -> String {
        let parts = name
            .split(separator: " ")
            .compactMap { $0.first }
        let firstTwo = parts.prefix(2)
        return firstTwo.map { String($0) }.joined()
    }
    
    private func openSupportEmail() {
        let email = "support@prayerroom.app" // change later if needed
        let subject = "Prayer Room Feedback"
        let body = "Hi, I’d like to share some feedback about the Prayer Room app:"
        
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    // Daily Declaration helpers
    
    private func loadSavedDailyTime() {
        let calendar = Calendar.current
        let now = Date()
        
        let components = DateComponents(
            calendar: calendar,
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now),
            day: calendar.component(.day, from: now),
            hour: dailyDeclarationHour,
            minute: dailyDeclarationMinute
        )
        
        if let date = calendar.date(from: components) {
            dailyDeclarationTime = date
        }
    }
    
    private func updateDailyDeclarationSchedule() {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: dailyDeclarationTime)
        let hour = comps.hour ?? 7
        let minute = comps.minute ?? 0
        
        dailyDeclarationHour = hour
        dailyDeclarationMinute = minute
        
        if dailyDeclarationEnabled {
            NotificationManager.shared.scheduleDailyDeclarationNotification(
                hour: hour,
                minute: minute
            )
        } else {
            NotificationManager.shared.cancelDailyDeclarationNotification()
        }
    }
}

// MARK: - Reusable UI Bits

struct SettingsSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PrayerTheme.textSecondary)
                .textCase(.uppercase)
        }
    }
}

struct SettingsIconCircle: View {
    let systemName: String
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - How Prayer Room Works (Instructions)

struct HowPrayerRoomWorksView: View {
    var body: some View {
        ZStack {
            PrayerTheme.gradient
                .ignoresSafeArea()
            
            TabView {
                instructionsPage(
                    icon: "hands.sparkles.fill",
                    title: "Prayer Wall",
                    description: """
Post what you’re walking through and let others stand with you in prayer. Tap “I’m praying” to encourage others and keep track of prayers you’ve lifted up.
"""
                )
                
                instructionsPage(
                    icon: "quote.bubble.fill",
                    title: "Testimonies",
                    description: """
Share stories of what God has done. Testimonies help build faith, close the loop on answered prayers, and remind the community that God is moving.
"""
                )
                
                instructionsPage(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Thread Stories",
                    description: """
Use comments and updates to keep a prayer request or testimony going over time. Think of it like a living story that others can follow and encourage.
"""
                )
                
                instructionsPage(
                    icon: "rosette",
                    title: "Encouragement Badges",
                    description: """
As you pray for others, share testimonies, and encourage people in the comments, you’ll unlock badges that quietly celebrate your faithfulness.
"""
                )
                
                instructionsPage(
                    icon: "chart.bar.fill",
                    title: "Proclaim Meter",
                    description: """
Your Proclaim Meter grows as you give prayers, receive prayers, and share testimonies. It’s a gentle reminder of how your voice is strengthening this community.
"""
                )
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        }
        .navigationTitle("How Prayer Room Works")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func instructionsPage(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            
            Image(systemName: icon)
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.white)
                .padding(20)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PrayerTheme.accent, PrayerTheme.highlight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(description)
                .font(.system(size: 15))
                .foregroundColor(PrayerTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}

// MARK: - Community Guidelines Screen

struct CommunityGuidelinesView: View {
    var body: some View {
        ZStack {
            PrayerTheme.gradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Community Guidelines")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("""
This is a space for prayer, encouragement, and hope. To keep this community safe and honoring:

• Be kind and respectful in your words.
• Focus on prayer and encouragement, not debate.
• Do not shame, judge, or attack others.
                        • Do not share personal details about others without their consent.
• This app is not a substitute for medical, legal, or emergency help. If you or someone you know is in crisis, contact local emergency services or a trusted professional immediately.
""")
                        .font(.system(size: 14))
                        .foregroundColor(PrayerTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text("Thank you for helping make this a safe space for people to share prayers and testimonies.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer(minLength: 24)
                }
                .padding()
            }
        }
        .navigationTitle("Guidelines")
        .navigationBarTitleDisplayMode(.inline)
    }
}
