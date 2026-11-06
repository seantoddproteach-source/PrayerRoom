//
//  PrayerStore.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/13/25.
//

import Foundation
import SwiftUI
import CloudKit

// MARK: - Global Directory User (for People search)

struct DirectoryUser: Identifiable, Hashable {
    /// CloudKit recordName of the UserProfile record
    let id: String
    let displayName: String
    let username: String?
    let bio: String?
}

// MARK: - PrayerStore

@MainActor
final class PrayerStore: ObservableObject {
    // MARK: - Published State

    @Published var prayers: [PrayerRequest] = []
    @Published var testimonies: [Testimony] = []
    @Published var profile: UserProfile
    @Published var newlyUnlockedBadge: EncouragementBadge? = nil
    @Published var moderationMessage: String? = nil

    /// Cache of global stats keyed by displayName
    @Published private(set) var userStatsCache: [String: UserStats] = [:]

    /// Remote profile cache (used for avatars in Testimony feed, PersonProfileView, etc.)
    /// Keyed by "u:@username" when available, else "n:Display Name"
    private var remoteProfileCache: [String: UserProfile] = [:]

    /// Internal so extensions in other files can use it
    let cloud = CloudKitService.shared

    // MARK: - Init

    init() {
        self.profile = UserProfile(
            id: UUID(),
            displayName: "New User",
            username: "@username",
            age: "",
            location: "",
            bio: "",
            profileImageData: nil,
            partners: [],
            prayersGiven: 0,
            prayersReceived: 0,
            savedPrayerIds: [],
            prayedPrayerIds: [],
            blockedNames: [],
            primaryFocus: nil,
            cloudKitRecordName: "",
            unlockedBadgeIDs: []
        )

        let appleName = appleFullName
        if !appleName.isEmpty {
            self.profile.displayName = appleName
        }

        Task {
            await loadFromCloud()
        }
    }

    // MARK: - Private Helpers

    /// Reassigns the entire profile so SwiftUI always refreshes correctly.
    private func updateProfile(_ mutate: (inout UserProfile) -> Void) {
        var updated = profile
        mutate(&updated)
        profile = updated
    }

    // MARK: - CloudKit Error Logging

    private func logCloudError(_ error: Error, context: String) {
        if let ck = error as? CKError {
            print("❌ \(context) CKError:", ck.code, ck.localizedDescription)
            if ck.code == .permissionFailure {
                print("🔒 permissionFailure: likely cannot update someone else’s record in public DB.")
            }
        } else {
            print("❌ \(context) error:", error)
        }
    }

    // MARK: - Reporting / Badges

    func reportContent(
        contentType: String,
        contentId: String,
        reason: String
    ) {
        let reporterId = profile.id
        let reporterName = effectiveAuthorName

        Task {
            do {
                try await cloud.reportContent(
                    contentType: contentType,
                    contentId: contentId,
                    reportedByUserId: reporterId,
                    reportedByName: reporterName,
                    reason: reason
                )

                print("🚩 Content reported successfully")
            } catch {
                print("❌ Failed to report content:", error)
            }
        }
    }

    func checkForNewBadges() {
        let unlockedNow = encouragementBadges.filter { $0.isUnlocked }
        let alreadyUnlocked = profile.unlockedBadgeIDs

        let newBadges = unlockedNow.filter { !alreadyUnlocked.contains($0.id) }
        guard !newBadges.isEmpty else { return }

        updateProfile { profile in
            for badge in newBadges {
                profile.unlockedBadgeIDs.insert(badge.id)
            }
        }

        if let firstNew = newBadges.first {
            newlyUnlockedBadge = firstNew
            print("🏅 New badge unlocked:", firstNew.title)
        }

        Task {
            await saveProfileToCloud()
        }
    }

    // MARK: - Load from CloudKit

    func loadFromCloud() async {
        do {
            var loadedProfile = try await cloud.fetchCurrentUserProfile()
            let basePrayers = try await cloud.fetchRecentPrayers()
            let loadedTestimonies = try await cloud.fetchRecentTestimonies()

            let appleName = appleFullName
            let trimmedCloudName = loadedProfile.displayName
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !appleName.isEmpty,
               (trimmedCloudName.isEmpty || trimmedCloudName == "New User") {
                loadedProfile.displayName = appleName

                do {
                    let saved = try await cloud.saveProfile(loadedProfile)
                    loadedProfile = saved
                } catch {
                    print("⚠️ Failed to push Apple name to CloudKit profile:", error)
                }
            }

            self.profile = loadedProfile
            self.prayers = basePrayers
            self.testimonies = loadedTestimonies

            Task { @MainActor in
                let hydratedPrayers = await self.hydratePrayerInteractions(basePrayers)
                self.prayers = hydratedPrayers
            }

            do {
                try await cloud.setupNotificationSubscriptionsForCurrentUser()
                print("✅ Notification subscription ready for current user")
            } catch {
                print("⚠️ Failed to set up notification subscriptions:", error)
            }

            print("✅ Loaded profile from CloudKit with recordName: \(self.profile.cloudKitRecordName)")
        } catch {
            print("❌ Failed to load from CloudKit:", error)
        }
    }

    // MARK: - Refresh

    func refreshPrayers() async {
        do {
            let latest = try await cloud.fetchRecentPrayers()

            self.prayers = latest

            Task { @MainActor in
                let hydrated = await self.hydratePrayerInteractions(latest)
                self.prayers = hydrated
            }
        } catch {
            print("❌ Failed to refresh prayers from CloudKit:", error)
        }
    }

    func refreshTestimonies() async {
        do {
            let latest = try await cloud.fetchRecentTestimonies()
            self.testimonies = latest
        } catch {
            print("❌ Failed to refresh testimonies from CloudKit:", error)
        }
    }

    func refreshAll() async {
        do {
            let latestPrayers = try await cloud.fetchRecentPrayers()
            let latestTestimonies = try await cloud.fetchRecentTestimonies()

            self.prayers = latestPrayers
            self.testimonies = latestTestimonies

            Task { @MainActor in
                let hydratedPrayers = await self.hydratePrayerInteractions(latestPrayers)
                self.prayers = hydratedPrayers
            }
        } catch {
            print("❌ Failed to refresh all from CloudKit:", error)
        }
    }

    private func hydratePrayerInteractions(_ prayers: [PrayerRequest]) async -> [PrayerRequest] {
        var hydrated: [PrayerRequest] = []

        for var prayer in prayers {
            do {
                let comments = try await cloud.fetchPrayerComments(for: prayer.id)
                let prayCount = try await cloud.fetchPrayerPrayCount(for: prayer.id)

                prayer.comments = comments
                prayer.prayersCount = prayCount
            } catch {
                print("⚠️ Failed to hydrate prayer interactions for \(prayer.id):", error)
            }

            hydrated.append(prayer)
        }

        return hydrated
    }

    // MARK: - GLOBAL DIRECTORY SEARCH

    func searchDirectoryUsers(matching query: String) async throws -> [DirectoryUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await cloud.searchUserProfiles(matching: trimmed)
    }

    // MARK: - GLOBAL USER STATS

    func stats(for displayName: String) -> UserStats? {
        userStatsCache[displayName]
    }

    func loadStatsIfNeeded(for displayName: String) async {
        let key = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        if userStatsCache[key] != nil {
            return
        }

        do {
            let stats = try await cloud.fetchUserStats(forDisplayName: key)
            userStatsCache[key] = stats
        } catch {
            print("❌ Failed to load stats for \(key):", error)
        }
    }

    // MARK: - Helpers

    func prayer(withId id: UUID) -> PrayerRequest? {
        prayers.first(where: { $0.id == id })
    }

    private func indexOfPrayer(id: UUID) -> Int? {
        prayers.firstIndex(where: { $0.id == id })
    }

    private var appleFullName: String {
        UserDefaults.standard.string(forKey: "appleFullName")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var effectiveAuthorName: String {
        let profileName = profile.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !profileName.isEmpty && profileName != "New User" {
            return profileName
        }

        let appleName = appleFullName
        if !appleName.isEmpty {
            return appleName
        }

        return "Anonymous"
    }

    // MARK: - Central Profile Save Helper

    func saveProfileToCloud() async {
        print("📤 Saving profile to CloudKit…")
        print("   Current partners: \(profile.partners.map { $0.name })")
        print("   Blocked names: \(profile.blockedNames)")
        print("   Saved prayers count: \(profile.savedPrayerIds.count)")
        print("   Unlocked badges: \(profile.unlockedBadgeIDs)")

        do {
            let saved = try await cloud.saveProfile(self.profile)
            self.profile = saved

            print("✅ Profile saved to CloudKit successfully.")
            print("   Saved partners now: \(profile.partners.map { $0.name })")
            print("   Blocked names now: \(profile.blockedNames)")
            print("   Saved prayers count now: \(profile.savedPrayerIds.count)")
            print("   Unlocked badges now: \(profile.unlockedBadgeIDs)")
        } catch {
            print("❌ Failed to save profile to CloudKit:")
            print("   \(error)")
        }
    }

    // MARK: - Notification Helper

    private func sendNotificationIfNeeded(
        recipientUserId: UUID?,
        type: String,
        title: String,
        body: String,
        prayerId: UUID? = nil
    ) async {
        guard let recipientUserId else { return }
        guard recipientUserId != profile.id else { return }

        do {
            try await cloud.sendAppNotification(
                recipientUserId: recipientUserId.uuidString,
                senderUserId: profile.id.uuidString,
                senderName: effectiveAuthorName,
                type: type,
                title: title,
                body: body,
                prayerId: prayerId
            )
        } catch {
            logCloudError(error, context: "sendAppNotification")
        }
    }

    // MARK: - Add Prayer

    func addPrayer(
        text: String,
        authorName: String? = nil,
        categories: [PrayerCategory] = [.other],
        ownerId: UUID? = nil
    ) {
        let finalCategories = categories.isEmpty ? [.other] : categories
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let moderation = ModerationService.moderate(trimmedText)

        switch moderation {
        case .clean:
            break
        case .flagged(let reason):
            print("⚠️ Prayer flagged:", reason)
        case .blocked(let reason):
            print("❌ Prayer blocked:", reason)
            self.moderationMessage = reason
            return
        }

        let resolvedAuthorName: String
        if let explicit = authorName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            resolvedAuthorName = explicit
        } else {
            resolvedAuthorName = effectiveAuthorName
        }

        let finalOwnerId = ownerId ?? profile.id

        let prayer = PrayerRequest(
            authorName: resolvedAuthorName,
            text: trimmedText,
            timestamp: Date(),
            prayersCount: 0,
            comments: [],
            categories: finalCategories,
            ownerId: finalOwnerId
        )

        self.prayers.insert(prayer, at: 0)

        Task { @MainActor in
            do {
                let saved = try await cloud.savePrayer(prayer)
                if let idx = self.prayers.firstIndex(where: { $0.id == prayer.id }) {
                    self.prayers[idx] = saved
                }
                self.checkForNewBadges()
            } catch {
                self.logCloudError(error, context: "addPrayer")
                self.prayers.removeAll { $0.id == prayer.id }
            }
        }
    }

    // MARK: - Delete Prayer

    func deletePrayer(_ prayer: PrayerRequest) {
        if let index = prayers.firstIndex(where: { $0.id == prayer.id }) {
            prayers.remove(at: index)
        }

        Task {
            do {
                try await cloud.deletePrayer(id: prayer.id)
            } catch {
                self.logCloudError(error, context: "deletePrayer")
            }
        }
    }

    // MARK: - Delete Testimony

    func deleteTestimony(_ testimony: Testimony) {
        if let index = testimonies.firstIndex(where: { $0.id == testimony.id }) {
            testimonies.remove(at: index)
        }

        Task {
            do {
                try await cloud.deleteTestimony(id: testimony.id)
            } catch {
                self.logCloudError(error, context: "deleteTestimony")
            }
        }
    }

    // MARK: - Comments

    func addComment(to prayerId: UUID, authorName: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let index = indexOfPrayer(id: prayerId) else {
            print("❌ addComment: prayer not found for id \(prayerId)")
            return
        }

        let moderation = ModerationService.moderate(trimmed)

        switch moderation {
        case .clean:
            break
        case .flagged(let reason):
            print("⚠️ Comment flagged:", reason)
        case .blocked(let reason):
            print("❌ Comment blocked:", reason)
            self.moderationMessage = reason
            return
        }

        print("💬 Adding comment")
        print("   prayerId:", prayerId)
        print("   author:", authorName)
        print("   text:", trimmed)

        let localComment = Comment(
            id: UUID().uuidString,
            prayerId: prayerId.uuidString,
            authorName: authorName,
            authorUserId: profile.id,
            text: trimmed,
            timestamp: Date()
        )

        prayers[index].comments.append(localComment)
        let prayerOwnerId = prayers[index].ownerId
        let currentProfileId = profile.id

        Task { @MainActor in
            do {
                print("☁️ Saving PrayerComment to CloudKit")

                let savedComment = try await cloud.savePrayerComment(
                    prayerId: prayerId,
                    authorName: authorName,
                    authorUserId: currentProfileId,
                    text: trimmed,
                    timestamp: localComment.timestamp
                )

                if let latestIndex = self.prayers.firstIndex(where: { $0.id == prayerId }) {
                    if let localIndex = self.prayers[latestIndex].comments.firstIndex(where: { $0.id == localComment.id }) {
                        self.prayers[latestIndex].comments[localIndex] = savedComment
                    } else {
                        self.prayers[latestIndex].comments.append(savedComment)
                    }
                }

                print("✅ Comment saved to CloudKit")

                await self.sendNotificationIfNeeded(
                    recipientUserId: prayerOwnerId,
                    type: "prayer_comment",
                    title: "New Comment on Your Prayer",
                    body: "\(self.effectiveAuthorName) commented on your prayer.",
                    prayerId: prayerId
                )

                self.checkForNewBadges()

            } catch {
                print("❌ Failed to save PrayerComment to CloudKit")
                self.logCloudError(error, context: "addComment")

                if let latestIndex = self.prayers.firstIndex(where: { $0.id == prayerId }) {
                    self.prayers[latestIndex].comments.removeAll { $0.id == localComment.id }
                }
            }
        }
    }

    func editComment(_ comment: Comment, newText: String) {
        guard comment.authorUserId == profile.id else {
            print("❌ Cannot edit someone else's comment")
            return
        }

        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let moderation = ModerationService.moderate(trimmed)

        switch moderation {
        case .clean:
            break
        case .flagged(let reason):
            print("⚠️ Edited comment flagged:", reason)
        case .blocked(let reason):
            print("❌ Edited comment blocked:", reason)
            self.moderationMessage = reason
            return
        }

        guard let prayerUUID = UUID(uuidString: comment.prayerId) else {
            print("❌ editComment: invalid prayerId \(comment.prayerId)")
            return
        }

        guard let prayerIndex = prayers.firstIndex(where: { $0.id == prayerUUID }),
              let commentIndex = prayers[prayerIndex].comments.firstIndex(where: { $0.id == comment.id }) else {
            print("❌ editComment: comment not found locally")
            return
        }

        let oldText = prayers[prayerIndex].comments[commentIndex].text
        prayers[prayerIndex].comments[commentIndex].text = trimmed

        Task { @MainActor in
            do {
                try await cloud.updatePrayerComment(commentId: comment.id, newText: trimmed)
                print("✅ Comment updated in CloudKit")
            } catch {
                self.prayers[prayerIndex].comments[commentIndex].text = oldText
                self.logCloudError(error, context: "editComment")
            }
        }
    }

    func deleteComment(_ comment: Comment) {
        guard comment.authorUserId == profile.id else {
            print("❌ Cannot delete someone else's comment")
            return
        }

        guard let prayerUUID = UUID(uuidString: comment.prayerId) else {
            print("❌ deleteComment: invalid prayerId \(comment.prayerId)")
            return
        }

        guard let prayerIndex = prayers.firstIndex(where: { $0.id == prayerUUID }),
              let commentIndex = prayers[prayerIndex].comments.firstIndex(where: { $0.id == comment.id }) else {
            print("❌ deleteComment: comment not found locally")
            return
        }

        let removedComment = prayers[prayerIndex].comments.remove(at: commentIndex)

        Task { @MainActor in
            do {
                try await cloud.deletePrayerComment(commentId: removedComment.id)
                print("✅ Comment deleted from CloudKit")
            } catch {
                self.prayers[prayerIndex].comments.insert(removedComment, at: commentIndex)
                self.logCloudError(error, context: "deleteComment")
            }
        }
    }

    // MARK: - Testimonies

    func editTestimony(_ testimony: Testimony, newTitle: String, newText: String) {
        guard testimony.ownerId == profile.id else {
            print("❌ Cannot edit someone else's testimony")
            return
        }

        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let moderation = ModerationService.moderate("\(trimmedTitle) \(trimmedText)")

        switch moderation {
        case .clean:
            break
        case .flagged(let reason):
            print("⚠️ Edited testimony flagged:", reason)
        case .blocked(let reason):
            print("❌ Edited testimony blocked:", reason)
            self.moderationMessage = reason
            return
        }

        guard let index = testimonies.firstIndex(where: { $0.id == testimony.id }) else {
            print("❌ editTestimony: testimony not found locally")
            return
        }

        let oldValue = testimonies[index]

        testimonies[index].title = trimmedTitle
        testimonies[index].text = trimmedText

        Task { @MainActor in
            do {
                let saved = try await cloud.saveTestimony(testimonies[index])
                if let latestIndex = self.testimonies.firstIndex(where: { $0.id == testimony.id }) {
                    self.testimonies[latestIndex] = saved
                }
                print("✅ Testimony updated in CloudKit")
            } catch {
                self.testimonies[index] = oldValue
                print("❌ Failed to update testimony in CloudKit:", error)
            }
        }
    }

    // MARK: - Mark "I'm Praying"

    func markPraying(for prayerId: UUID) {
        if profile.prayedPrayerIds.contains(prayerId) {
            return
        }

        guard let index = indexOfPrayer(id: prayerId) else {
            print("❌ markPraying: prayer not found for id \(prayerId)")
            return
        }

        let prayerOwnerId = prayers[index].ownerId
        let author = prayers[index].authorName
        let currentProfileId = profile.id
        let currentAuthorName = effectiveAuthorName

        prayers[index].prayersCount += 1

        updateProfile { profile in
            profile.prayedPrayerIds.insert(prayerId)

            if author == currentAuthorName {
                profile.prayersReceived += 1
            } else {
                profile.prayersGiven += 1
            }
        }

        Task { @MainActor in
            do {
                print("🙏 Saving PrayerPray to CloudKit")

                let newCount = try await cloud.savePrayerPray(
                    prayerId: prayerId,
                    userId: currentProfileId,
                    userName: currentAuthorName
                )

                if let latestIndex = self.prayers.firstIndex(where: { $0.id == prayerId }) {
                    self.prayers[latestIndex].prayersCount = newCount
                }

                print("✅ PrayerPray saved to CloudKit")

                await self.sendNotificationIfNeeded(
                    recipientUserId: prayerOwnerId,
                    type: "prayer_like",
                    title: "Someone Prayed for You",
                    body: "\(currentAuthorName) prayed for your request.",
                    prayerId: prayerId
                )

                self.checkForNewBadges()
                await self.saveProfileToCloud()

            } catch {
                self.logCloudError(error, context: "markPraying")

                if let latestIndex = self.prayers.firstIndex(where: { $0.id == prayerId }) {
                    self.prayers[latestIndex].prayersCount =
                        max(0, self.prayers[latestIndex].prayersCount - 1)
                }

                self.updateProfile { profile in
                    profile.prayedPrayerIds.remove(prayerId)

                    if author == currentAuthorName {
                        profile.prayersReceived = max(0, profile.prayersReceived - 1)
                    } else {
                        profile.prayersGiven = max(0, profile.prayersGiven - 1)
                    }
                }
            }
        }
    }

    // MARK: - Saved / Bookmarked Prayers

    func isSaved(prayerId: UUID) -> Bool {
        profile.savedPrayerIds.contains(prayerId)
    }

    func toggleSaved(prayerId: UUID) {
        updateProfile { profile in
            if profile.savedPrayerIds.contains(prayerId) {
                profile.savedPrayerIds.remove(prayerId)
            } else {
                profile.savedPrayerIds.insert(prayerId)
            }
        }

        Task {
            await self.saveProfileToCloud()
        }
    }

    // MARK: - Prayer Partners

    func addPrayerPartner(name: String, note: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        print("➡️ FOLLOW REQUEST: Trying to follow \(trimmedName)")

        if profile.partners.contains(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            print("ℹ️ FOLLOW: Already following \(trimmedName), skipping.")
            return
        }

        let partner = PrayerPartner(
            name: trimmedName,
            note: trimmedNote
        )

        updateProfile { profile in
            profile.partners.append(partner)
        }

        print("✅ FOLLOWED: \(trimmedName). Saving to CloudKit...")
        Task { @MainActor in
            await self.saveProfileToCloud()
            self.checkForNewBadges()

            do {
                let targetProfile = try await self.cloud.fetchProfile(
                    displayName: trimmedName,
                    username: trimmedNote.isEmpty ? nil : trimmedNote
                )

                await self.sendNotificationIfNeeded(
                    recipientUserId: targetProfile?.id,
                    type: "follow",
                    title: "New Prayer Partner",
                    body: "\(self.effectiveAuthorName) followed you as a prayer partner."
                )
            } catch {
                self.logCloudError(error, context: "followNotification")
            }
        }
    }

    func removePrayerPartner(id: UUID) {
        if let partner = profile.partners.first(where: { $0.id == id }) {
            print("🚫 UNFOLLOW BY ID: \(partner.name). Saving to CloudKit...")
        }

        updateProfile { profile in
            profile.partners.removeAll { $0.id == id }
        }

        Task {
            await self.saveProfileToCloud()
        }
    }

    func removePrayerPartner(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        updateProfile { profile in
            profile.partners.removeAll {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(trimmedName) == .orderedSame
            }
        }

        print("🚫 UNFOLLOWED: \(name). Saving to CloudKit...")
        Task {
            await self.saveProfileToCloud()
        }
    }
}

// MARK: - Remote Profiles

extension PrayerStore {

    func loadRemoteProfileForPerson(displayName: String, username: String?) async -> UserProfile? {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = (username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let key: String
        if !trimmedUsername.isEmpty, trimmedUsername != "@username" {
            key = "u:\(trimmedUsername)"
        } else {
            guard !trimmedName.isEmpty else { return nil }
            key = "n:\(trimmedName)"
        }

        if let cached = remoteProfileCache[key] {
            return cached
        }

        do {
            let fetched = try await cloud.fetchProfile(
                displayName: trimmedName,
                username: trimmedUsername.isEmpty ? nil : trimmedUsername
            )

            if let fetched {
                remoteProfileCache[key] = fetched
            }

            return fetched
        } catch {
            logCloudError(error, context: "loadRemoteProfileForPerson")
            return nil
        }
    }
}

// MARK: - Follow & Block Helpers

extension PrayerStore {
    func isFollowing(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        return profile.partners.contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    func follow(name: String, note: String = "") {
        addPrayerPartner(name: name, note: note)
    }

    func unfollow(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let partner = profile.partners.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            removePrayerPartner(id: partner.id)
        }
    }

    func isBlocked(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return profile.blockedNames.contains(trimmed)
    }

    func blockUser(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        updateProfile { profile in
            profile.blockedNames.insert(trimmed)
        }

        Task {
            await self.saveProfileToCloud()
        }
    }

    func unblockUser(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        updateProfile { profile in
            profile.blockedNames.remove(trimmed)
        }

        Task {
            await self.saveProfileToCloud()
        }
    }
}
