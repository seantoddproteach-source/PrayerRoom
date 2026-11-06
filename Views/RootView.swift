//
//  RootView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/16/25.
//

import SwiftUI

// If your @main still uses `RootView`, this keeps it working:
struct RootView1: View {
    @EnvironmentObject var store: PrayerStore
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenInstructions") private var hasSeenInstructions = false
    
    @State private var showSplash = true
    @State private var showInstructions = false
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                mainAppBody
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.03)),
                        removal: .opacity
                    ))
            }
        }
        // Fade between splash and app
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        // Nice spring when onboarding completes → ContentView
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: hasCompletedOnboarding)
        .onAppear {
            // How long the splash shows before moving on
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSplash = false
                }
                
                // Once splash is done, if onboarding is already finished
                // and the user has never seen instructions, show them.
                if hasCompletedOnboarding && !hasSeenInstructions {
                    showInstructions = true
                }
            }
        }
        // If they finish onboarding while the app is already running
        .onChange(of: hasCompletedOnboarding) { newValue in
            if newValue && !showSplash && !hasSeenInstructions {
                showInstructions = true
            }
        }
        // Show the multi-screen “How Prayer Room Works” walkthrough
        .sheet(isPresented: $showInstructions, onDismiss: {
            hasSeenInstructions = true
        }) {
            InstructionsView()
        }
        // ✅ CloudKit subscriptions, called directly (no dynamicMember issues)
        .task {
            await configureCloudKitSubscriptions()
        }
    }
    
    // MARK: - Main App Body (Onboarding vs Tabs)
    
    @ViewBuilder
    private var mainAppBody: some View {
        if hasCompletedOnboarding {
            ContentView()
        } else {
            OnboardingView()
        }
    }
    
    // MARK: - CloudKit Subscriptions Helper
    
    private func configureCloudKitSubscriptions() async {
        do {
            try await CloudKitService.shared.setupNotificationSubscriptionsForCurrentUser()
            print("✅ CloudKit subscriptions configured for current user")
        } catch {
            print("❌ Failed to set up CloudKit subscriptions:", error)
        }
    }
}
