//
//  Models.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/13/25.
//
import Foundation

// MARK: - Comment

struct Comment: Identifiable, Hashable, Codable {
    
    /// CloudKit recordName
    var id: String
    
    /// Prayer this comment belongs to
    var prayerId: String
    
    /// Display name shown in UI
    var authorName: String
    
    /// UserProfile.id of the commenter
    var authorUserId: UUID
    
    /// Comment text
    var text: String
    
    /// When it was posted
    var timestamp: Date
    
    
    init(
        id: String = UUID().uuidString,
        prayerId: String,
        authorName: String,
        authorUserId: UUID,
        text: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.prayerId = prayerId
        self.authorName = authorName
        self.authorUserId = authorUserId
        self.text = text
        self.timestamp = timestamp
    }
}
// MARK: - Prayer Category / Tags

enum PrayerCategory: String, CaseIterable, Identifiable, Hashable {
    case healing = "Healing"
    case family = "Family"
    case provision = "Provision"
    case guidance = "Guidance"
    case protection = "Protection"
    case mentalHealth = "Mental Health"
    case praise = "Praise"
    case other = "Other"
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .healing:      return "💜"
        case .family:       return "👨‍👩‍👧"
        case .provision:    return "💰"
        case .guidance:     return "🧭"
        case .protection:   return "🛡️"
        case .mentalHealth: return "🧠"
        case .praise:       return "✨"
        case .other:        return "🙏"
        }
    }
}

// MARK: - Prayer Request

struct PrayerRequest: Identifiable, Hashable {
    let id: UUID
    var authorName: String
    var text: String
    var timestamp: Date
    var prayersCount: Int
    var comments: [Comment]
    var categories: [PrayerCategory]
    
    /// Which user/profile this prayer belongs to (used for "Your Prayers")
    var ownerId: UUID?
    
    init(
        id: UUID = UUID(),
        authorName: String,
        text: String,
        timestamp: Date = Date(),
        prayersCount: Int = 0,
        comments: [Comment] = [],
        categories: [PrayerCategory] = [.other],
        ownerId: UUID? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.text = text
        self.timestamp = timestamp
        self.prayersCount = prayersCount
        self.comments = comments
        self.categories = categories
        self.ownerId = ownerId
    }
}

// MARK: - Testimony

struct Testimony: Identifiable, Hashable {
    let id: UUID
    var authorName: String
    var title: String
    var text: String
    var timestamp: Date
    
    /// Which user/profile this testimony belongs to (used for "Your Testimonies")
    var ownerId: UUID?
    
    /// 🔗 If non-nil, this testimony is part of a Story Thread
    /// for the prayer with this ID.
    var linkedPrayerId: UUID?
    
    init(
        id: UUID = UUID(),
        authorName: String,
        title: String,
        text: String,
        timestamp: Date = Date(),
        ownerId: UUID? = nil,
        linkedPrayerId: UUID? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.title = title
        self.text = text
        self.timestamp = timestamp
        self.ownerId = ownerId
        self.linkedPrayerId = linkedPrayerId
    }
}

// MARK: - Prayer Partner

struct PrayerPartner: Identifiable, Hashable {
    let id: UUID = UUID()
    var name: String
    var note: String
    var since: Date = Date()
}

// MARK: - User Profile

struct UserProfile: Identifiable, Hashable {
    var id: UUID
    var displayName: String
    var username: String
    var age: String
    var location: String
    var bio: String
    var profileImageData: Data?
    var partners: [PrayerPartner]
    var prayersGiven: Int
    var prayersReceived: Int
    var savedPrayerIds: Set<UUID>
    var prayedPrayerIds: Set<UUID>
    var blockedNames: Set<String>          // 👈 NEW
    var primaryFocus: PrayerCategory?
    var cloudKitRecordName: String
    var unlockedBadgeIDs: Set<String> = []

    init(
        id: UUID,
        displayName: String,
        username: String,
        age: String,
        location: String,
        bio: String,
        profileImageData: Data?,
        partners: [PrayerPartner],
        prayersGiven: Int,
        prayersReceived: Int,
        savedPrayerIds: Set<UUID>,
        prayedPrayerIds: Set<UUID>,
        blockedNames: Set<String> = [],    // 👈 default so older calls still work
        primaryFocus: PrayerCategory?,
        cloudKitRecordName: String,
        unlockedBadgeIDs: Set<String> = []
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.age = age
        self.location = location
        self.bio = bio
        self.profileImageData = profileImageData
        self.partners = partners
        self.prayersGiven = prayersGiven
        self.prayersReceived = prayersReceived
        self.savedPrayerIds = savedPrayerIds
        self.prayedPrayerIds = prayedPrayerIds
        self.blockedNames = blockedNames
        self.primaryFocus = primaryFocus
        self.cloudKitRecordName = cloudKitRecordName
    }
}
