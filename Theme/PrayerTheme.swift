//
//  PrayerTheme.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/13/25.
//

import SwiftUI

struct PrayerTheme {
    // Core colors
    static let accent = Color(red: 0.27, green: 0.49, blue: 0.98)       // Modern blue
    static let accentSoft = Color(red: 0.56, green: 0.71, blue: 1.0)    // Lighter blue
    static let highlight = Color(red: 0.64, green: 0.52, blue: 1.0)     // Blue-purple
    
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    
    // Background gradient for the whole app
    static let gradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.12, blue: 0.25),
            Color(red: 0.10, green: 0.24, blue: 0.45),
            Color(red: 0.26, green: 0.21, blue: 0.48)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    /// Glass card style
    func prayerCard() -> some View {
        self
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(radius: 10, y: 6)
    }
    
    /// Primary button style
    func prayerPrimaryButton() -> some View {
        self
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [PrayerTheme.accent, PrayerTheme.highlight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .font(.system(.subheadline, weight: .semibold))
            .cornerRadius(999)
            .shadow(radius: 12, y: 5)
    }
    
    /// Secondary chip/button style
    func prayerChip() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(999)
    }
}
