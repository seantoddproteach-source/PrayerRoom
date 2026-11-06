//
//  SignInView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/17/25.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authManager: AppleSignInManager

    var body: some View {
        ZStack {
            PrayerTheme.gradient
                .ignoresSafeArea()

            VStack(spacing: 32) {

                Spacer(minLength: 30)

                // MARK: - Logo + Tagline
                VStack(spacing: 16) {
                    // 🔹 Proclaim logo image from your asset catalog
                    Image("Proclaimimg")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260)     // tweak size if you want
                        .shadow(radius: 20, y: 10)

                    Text("Speak It. Believe It. Share It.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 10)

                // MARK: - Feature Row (updated for new vision)
                HStack(spacing: 12) {
                    featureChip(
                        icon: "hands.sparkles.fill",
                        title: "Pray",
                        subtitle: "Share what you’re believing for"
                    )
                    featureChip(
                        icon: "text.bubble.fill",
                        title: "Stories",
                        subtitle: "Thread updates as God moves"
                    )
                    featureChip(
                        icon: "sparkles",
                        title: "Proclaim",
                        subtitle: "Testimonies that encourage"
                    )
                }
                .padding(.horizontal)

                Spacer()

                // MARK: - Sign in with Apple Button
                SignInWithAppleButton(.continue) { request in
                    // Ask for name + email the first time
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleAuthorization(result: result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .cornerRadius(14)
                .padding(.horizontal, 32)

                Text("We’ll use your Apple ID to keep your Proclaim profile in sync across devices.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(PrayerTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
        }
    }

    // MARK: - Feature Chip

    private func featureChip(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(PrayerTheme.textSecondary)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(18)
    }
}
