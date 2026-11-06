//
//  PrayerStore+Badges.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/20/25.
//

import Foundation

struct EncouragementBadge: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let isUnlocked: Bool

    var description: String { subtitle }
}

@MainActor
extension PrayerStore {

    var encouragementBadges: [EncouragementBadge] {
        let prayersGiven = profile.prayersGiven
        let prayersPosted = prayersPostedCount
        let testimoniesPosted = testimoniesPostedCount
        let partnersCount = profile.partners.count
        let commentsGiven = commentsGivenCount

        return [
            EncouragementBadge(
                id: "first_amen",
                title: "First Amen",
                subtitle: "You marked your first “I’m praying” for someone.",
                systemImage: "hands.sparkles.fill",
                isUnlocked: prayersGiven >= 1
            ),
            EncouragementBadge(
                id: "faithful_intercessor",
                title: "Faithful Intercessor",
                subtitle: "You’ve prayed for at least 25 prayer requests.",
                systemImage: "hands.clap.fill",
                isUnlocked: prayersGiven >= 25
            ),
            EncouragementBadge(
                id: "prayer_warrior",
                title: "Prayer Warrior",
                subtitle: "You’ve prayed for 100+ requests in Prayer Room.",
                systemImage: "flame.fill",
                isUnlocked: prayersGiven >= 100
            ),
            EncouragementBadge(
                id: "storyteller",
                title: "Storyteller",
                subtitle: "You’ve shared 3 testimonies of God’s goodness.",
                systemImage: "quote.bubble.fill",
                isUnlocked: testimoniesPosted >= 3
            ),
            EncouragementBadge(
                id: "bold_witness",
                title: "Bold Witness",
                subtitle: "You’ve shared 10+ testimonies with the community.",
                systemImage: "megaphone.fill",
                isUnlocked: testimoniesPosted >= 10
            ),
            EncouragementBadge(
                id: "encourager",
                title: "Encourager",
                subtitle: "You’ve written 10 encouraging comments.",
                systemImage: "heart.text.square.fill",
                isUnlocked: commentsGiven >= 10
            ),
            EncouragementBadge(
                id: "super_encourager",
                title: "Super Encourager",
                subtitle: "You’ve written 40+ comments lifting others up.",
                systemImage: "sparkles",
                isUnlocked: commentsGiven >= 40
            ),
            EncouragementBadge(
                id: "circle_builder",
                title: "Circle Builder",
                subtitle: "You’ve added 3 prayer partners.",
                systemImage: "person.2.fill",
                isUnlocked: partnersCount >= 3
            ),
            EncouragementBadge(
                id: "circle_shepherd",
                title: "Circle Shepherd",
                subtitle: "You’ve added 8+ prayer partners.",
                systemImage: "person.3.sequence.fill",
                isUnlocked: partnersCount >= 8
            ),
            EncouragementBadge(
                id: "seed_sower",
                title: "Seed Sower",
                subtitle: "You’ve posted 3 prayer requests.",
                systemImage: "drop.fill",
                isUnlocked: prayersPosted >= 3
            ),
            EncouragementBadge(
                id: "house_of_prayer",
                title: "House of Prayer",
                subtitle: "You’ve posted 15+ prayer requests.",
                systemImage: "house.fill",
                isUnlocked: prayersPosted >= 15
            )
        ]
    }

    var unlockedEncouragementBadges: [EncouragementBadge] {
        encouragementBadges.filter { $0.isUnlocked }
    }

    var lockedEncouragementBadges: [EncouragementBadge] {
        encouragementBadges.filter { !$0.isUnlocked }
    }

    private var prayersPostedCount: Int {
        prayers.filter { prayer in
            if let ownerId = prayer.ownerId {
                return ownerId == profile.id
            } else {
                return prayer.authorName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(effectiveAuthorName) == .orderedSame
            }
        }
        .count
    }

    private var testimoniesPostedCount: Int {
        testimonies.filter { testimony in
            if let ownerId = testimony.ownerId {
                return ownerId == profile.id
            } else {
                return testimony.authorName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(effectiveAuthorName) == .orderedSame
            }
        }
        .count
    }

    private var commentsGivenCount: Int {
        prayers
            .flatMap { $0.comments }
            .filter { comment in
                comment.authorUserId == profile.id
            }
            .count
    }
}
