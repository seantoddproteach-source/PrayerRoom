//
//  ProclaimMeterView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/20/25.
//

import SwiftUI

struct ProclaimMeterView: View {
    @EnvironmentObject var store: PrayerStore

    // Build the meter directly from the PrayerStore
    private var meter: ProclaimMeterData {
        let myId = store.profile.id

        // Testimonies this user has posted
        let myTestimonies = store.testimonies.filter { testimony in
            if let ownerId = testimony.ownerId {
                return ownerId == myId
            } else {
                return testimony.authorName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(
                        store.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    ) == .orderedSame
            }
        }

        let testimonyPoints       = myTestimonies.count * 5
        let prayersGivenPoints    = store.profile.prayersGiven
        let prayersReceivedPoints = store.profile.prayersReceived

        let totalPoints = testimonyPoints + prayersGivenPoints + prayersReceivedPoints

        // Level thresholds & titles
        struct LevelConfig {
            let minPoints: Int
            let title: String
            let description: String
        }

        let levels: [LevelConfig] = [
            LevelConfig(
                minPoints: 0,
                title: "Getting Started",
                description: "Share your first story of what God has done."
            ),
            LevelConfig(
                minPoints: 25,
                title: "Faithful Voice",
                description: "You’re starting to regularly share prayers and testimonies."
            ),
            LevelConfig(
                minPoints: 75,
                title: "Bold Witness",
                description: "Your stories are strengthening others in their faith."
            ),
            LevelConfig(
                minPoints: 150,
                title: "Beacon of Hope",
                description: "You consistently proclaim God’s goodness in this community."
            )
        ]

        // Find current level
        var currentLevel = levels[0]
        var currentLevelIndex = 0

        for (index, level) in levels.enumerated() {
            if totalPoints >= level.minPoints {
                currentLevel = level
                currentLevelIndex = index
            } else {
                break
            }
        }

        // Next level (or keep growing past the last one)
        let nextLevelMinPoints: Int
        if currentLevelIndex < levels.count - 1 {
            nextLevelMinPoints = levels[currentLevelIndex + 1].minPoints
        } else {
            nextLevelMinPoints = currentLevel.minPoints + 100
        }

        // Progress within current level → next level
        let pointsIntoThisLevel   = max(0, totalPoints - currentLevel.minPoints)
        let pointsNeededThisLevel = max(1, nextLevelMinPoints - currentLevel.minPoints)
        let rawProgress           = Double(pointsIntoThisLevel) / Double(pointsNeededThisLevel)
        let clampedProgress       = min(max(rawProgress, 0.0), 1.0)

        return ProclaimMeterData(
            level: currentLevelIndex + 1,
            title: currentLevel.title,
            description: currentLevel.description,
            currentPoints: totalPoints,
            pointsForNext: nextLevelMinPoints,
            progress: clampedProgress
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PrayerTheme.accent, PrayerTheme.highlight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Text("\(meter.level)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Proclaim Meter")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(meter.title)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(PrayerTheme.textSecondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: meter.progress)
                    .tint(PrayerTheme.accent)

                HStack {
                    Text("\(meter.currentPoints) points")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Text("Next at \(meter.pointsForNext)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
            }

            Text(meter.description)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(PrayerTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(radius: 10, y: 6)
    }
}
