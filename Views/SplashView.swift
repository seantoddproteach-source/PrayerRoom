//
//  SplashView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/16/25.
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var taglineOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            PrayerTheme.gradient
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo + app name
                VStack(spacing: 12) {
                    // 🔹 Proclaim logo image from Assets
                    Image("Proclaimimg") // make sure this is the asset name
                        .resizable()
                        .scaledToFit()
                        .frame(width: 440, height: 440)
                        .shadow(radius: 18)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                    
                }
                
                // Tagline
                Text("Speak It. Believe It. Share It.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PrayerTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(taglineOpacity)
                
                Spacer()
                    .frame(height: 20)
            }
        }
        .onAppear {
            // Same “breathe in” animation
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.8).delay(0.4)) {
                taglineOpacity = 1.0
            }
        }
    }
}
