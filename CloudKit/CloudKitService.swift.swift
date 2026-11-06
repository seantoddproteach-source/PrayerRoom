//
//  CloudKitService.swift.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/16/25.
//

import Foundation
import CloudKit

/// Central place for all CloudKit reads/writes.
/// The rest of the app only talks to PrayerStore.
final class CloudKitService {
    static let shared = CloudKitService()

    // MARK: - Core CloudKit handles

    let container: CKContainer
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - Record Type Names

    private enum RecordType {
        static let profile         = "UserProfile"
        static let prayer          = "Prayer"
        static let testimony       = "Testimony"
        static let appNotification = "AppNotification"
        static let prayerComment   = "PrayerComment"
        static let prayerPray      = "PrayerPray"
    }

    // MARK: - Init

    private init() {
        let defaultContainer = CKContainer.default()
        self.container = defaultContainer

        #if DEBUG
        print("📦 CloudKitService using container:",
              defaultContainer.containerIdentifier ?? "nil")
        #endif
    }

    // MARK: - Helpers for Record IDs

    private func prayerRecordID(for prayer: PrayerRequest) -> CKRecord.ID {
        CKRecord.ID(recordName: "PRAYER_\(prayer.id.uuidString)")
    }

    private func prayerRecordID(for id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "PRAYER_\(id.uuidString)")
    }

    private func testimonyRecordID(for testimony: Testimony) -> CKRecord.ID {
        CKRecord.ID(recordName: "TESTIMONY_\(testimony.id.uuidString)")
    }

    private func testimonyRecordID(for id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "TESTIMONY_\(id.uuidString)")
    }

    private func profileRecordID(forUserRecordID userRecordID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "PROFILE_\(userRecordID.recordName)")
    }

    // MARK: - USER PROFILE
    
    func reportContent(
        contentType: String,
        contentId: String,
        reportedByUserId: UUID,
        reportedByName: String,
        reason: String,
        reportedUserName: String? = nil
    ) async throws {
        
        let record = CKRecord(recordType: "ContentReport")
        
        record["contentType"] = contentType as CKRecordValue
        record["contentId"] = contentId as CKRecordValue
        record["reportedByUserId"] = reportedByUserId.uuidString as CKRecordValue
        record["reportedByName"] = reportedByName as CKRecordValue
        record["reason"] = reason as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        
        _ = try await saveRecord(savedRecord: record)
    }
    
    func fetchCurrentUserProfile() async throws -> UserProfile {
        let userRecordID = try await container.userRecordID()
        let profileID = profileRecordID(forUserRecordID: userRecordID)

        do {
            let record = try await fetchRecord(with: profileID)
            return try userProfile(from: record)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                let defaultProfile = UserProfile(
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
                let saved = try await saveProfile(defaultProfile)
                return saved
            } else {
                throw error
            }
        }
    }

    func saveProfile(_ profile: UserProfile) async throws -> UserProfile {
        let userRecordID = try await container.userRecordID()
        let profileID = profileRecordID(forUserRecordID: userRecordID)

        func populate(_ record: CKRecord, from profile: UserProfile) throws {
            record["internalId"]      = profile.id.uuidString as CKRecordValue
            record["displayName"]     = profile.displayName as CKRecordValue
            record["username"]        = profile.username as CKRecordValue
            record["age"]             = profile.age as CKRecordValue
            record["location"]        = profile.location as CKRecordValue
            record["bio"]             = profile.bio as CKRecordValue
            record["prayersGiven"]    = profile.prayersGiven as CKRecordValue
            record["prayersReceived"] = profile.prayersReceived as CKRecordValue

            record["followersCount"] = profile.partners.count as CKRecordValue

            let blockedArray = Array(profile.blockedNames)
            record["blockedNames"] = blockedArray.isEmpty ? nil : blockedArray as CKRecordValue

            let partnerStrings = profile.partners.map { "\($0.name)||\($0.note)" }
            record["partners"] = partnerStrings.isEmpty ? nil : partnerStrings as CKRecordValue

            if let focus = profile.primaryFocus {
                record["primaryFocus"] = focus.rawValue as CKRecordValue
            } else {
                record["primaryFocus"] = nil
            }

            let savedStrings = profile.savedPrayerIds.map { $0.uuidString }
            let prayedStrings = profile.prayedPrayerIds.map { $0.uuidString }
            let unlockedBadgeArray = Array(profile.unlockedBadgeIDs)

            record["savedPrayerIds"]   = savedStrings.isEmpty ? nil : savedStrings as CKRecordValue
            record["prayedPrayerIds"]  = prayedStrings.isEmpty ? nil : prayedStrings as CKRecordValue
            record["unlockedBadgeIDs"] = unlockedBadgeArray.isEmpty ? nil : unlockedBadgeArray as CKRecordValue

            if let data = profile.profileImageData {
                let tempURL = try writeDataToTemporaryFile(data: data, fileName: "profileImage.dat")
                record["profileImage"] = CKAsset(fileURL: tempURL)
            } else {
                record["profileImage"] = nil
            }
        }

        for attempt in 0..<3 {
            do {
                let baseRecord: CKRecord
                do {
                    baseRecord = try await fetchRecord(with: profileID)
                } catch let innerError as CKError where innerError.code == .unknownItem {
                    print("ℹ️ No existing UserProfile record; creating a new one.")
                    baseRecord = CKRecord(recordType: RecordType.profile, recordID: profileID)
                } catch {
                    throw error
                }

                try populate(baseRecord, from: profile)

                let savedRecord = try await saveRecord(savedRecord: baseRecord)
                return try userProfile(from: savedRecord)
            } catch let ckError as CKError {
                if ckError.code == .serverRecordChanged {
                    print("⚠️ saveProfile conflict (\(ckError.localizedDescription)) on attempt \(attempt + 1), retrying…")
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continue
                } else {
                    throw ckError
                }
            } catch {
                throw error
            }
        }

        throw CKError(.serverRecordChanged)
    }

    // MARK: - PRAYERS

    func fetchRecentPrayers(limit: Int = 50) async throws -> [PrayerRequest] {
        let query = CKQuery(
            recordType: RecordType.prayer,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: limit)

            var prayers: [PrayerRequest] = []

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let p = try? decodePrayer(from: record) {
                        prayers.append(p)
                    }
                case .failure(let error):
                    print("⚠️ Failed to fetch prayer record:", error.localizedDescription)
                }
            }

            return prayers
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ No 'Prayer' record type exists yet in CloudKit. Returning empty list.")
            return []
        } catch {
            throw error
        }
    }

    func savePrayer(_ prayer: PrayerRequest) async throws -> PrayerRequest {
        let recordID = prayerRecordID(for: prayer)
        let record: CKRecord

        do {
            record = try await fetchRecord(with: recordID)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                record = CKRecord(recordType: RecordType.prayer, recordID: recordID)
            } else {
                throw error
            }
        }

        record["id"]           = prayer.id.uuidString as CKRecordValue
        record["authorName"]   = prayer.authorName as CKRecordValue
        record["text"]         = prayer.text as CKRecordValue
        record["timestamp"]    = prayer.timestamp as CKRecordValue
        record["prayersCount"] = prayer.prayersCount as CKRecordValue

        if let ownerId = prayer.ownerId {
            record["ownerId"] = ownerId.uuidString as CKRecordValue
        } else {
            record["ownerId"] = nil
        }

        let categoryStrings = prayer.categories.map { $0.rawValue }
        record["categories"] = categoryStrings as CKRecordValue

        let commentsStrings = prayer.comments.map { comment in
            let ts = comment.timestamp.timeIntervalSince1970
            return "\(comment.authorName)||\(comment.text)||\(ts)"
        }
        record["comments"] = commentsStrings.isEmpty ? nil : commentsStrings as CKRecordValue

        let saved = try await saveRecord(savedRecord: record)
        return try decodePrayer(from: saved)
    }

    func deletePrayer(id: UUID) async throws {
        let recordID = prayerRecordID(for: id)
        do {
            try await deleteRecord(with: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ Tried to delete prayer that no longer exists in CloudKit.")
        } catch {
            throw error
        }
    }

    func deleteTestimony(id: UUID) async throws {
        let recordID = testimonyRecordID(for: id)
        do {
            try await deleteRecord(with: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ Tried to delete testimony that no longer exists in CloudKit.")
        } catch {
            throw error
        }
    }

    // MARK: - PRAYER COMMENTS

    func fetchPrayerComments(for prayerId: UUID) async throws -> [Comment] {
        let predicate = NSPredicate(format: "prayerId == %@", prayerId.uuidString)
        let query = CKQuery(recordType: RecordType.prayerComment, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 200)

            var comments: [Comment] = []

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    let recordPrayerId = record["prayerId"] as? String ?? prayerId.uuidString
                    let authorName = record["authorName"] as? String ?? "Anonymous"
                    let authorUserIdString = record["authorUserId"] as? String ?? ""
                    let authorUserId = UUID(uuidString: authorUserIdString) ?? UUID()
                    let text = record["text"] as? String ?? ""
                    let timestamp = record["timestamp"] as? Date ?? Date()

                    comments.append(
                        Comment(
                            id: record.recordID.recordName,
                            prayerId: recordPrayerId,
                            authorName: authorName,
                            authorUserId: authorUserId,
                            text: text,
                            timestamp: timestamp
                        )
                    )
                case .failure(let error):
                    print("⚠️ Failed to fetch prayer comment:", error.localizedDescription)
                }
            }

            return comments
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ No PrayerComment record type exists yet in CloudKit. Returning empty comments.")
            return []
        } catch {
            throw error
        }
    }

    @discardableResult
    func savePrayerComment(
        prayerId: UUID,
        authorName: String,
        authorUserId: UUID,
        text: String,
        timestamp: Date = Date()
    ) async throws -> Comment {
        let record = CKRecord(recordType: RecordType.prayerComment)
        record["prayerId"] = prayerId.uuidString as CKRecordValue
        record["authorName"] = authorName as CKRecordValue
        record["authorUserId"] = authorUserId.uuidString as CKRecordValue
        record["text"] = text as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue

        let saved = try await saveRecord(savedRecord: record)

        return Comment(
            id: saved.recordID.recordName,
            prayerId: saved["prayerId"] as? String ?? prayerId.uuidString,
            authorName: saved["authorName"] as? String ?? authorName,
            authorUserId: UUID(uuidString: saved["authorUserId"] as? String ?? "") ?? authorUserId,
            text: saved["text"] as? String ?? text,
            timestamp: saved["timestamp"] as? Date ?? timestamp
        )
    }

    func updatePrayerComment(commentId: String, newText: String) async throws {
        let recordID = CKRecord.ID(recordName: commentId)
        let record = try await fetchRecord(with: recordID)
        record["text"] = newText as CKRecordValue
        _ = try await saveRecord(savedRecord: record)
    }

    func deletePrayerComment(commentId: String) async throws {
        let recordID = CKRecord.ID(recordName: commentId)
        try await deleteRecord(with: recordID)
    }

    // MARK: - PRAYER PRAYS

    func fetchPrayerPrayCount(for prayerId: UUID) async throws -> Int {
        let predicate = NSPredicate(format: "prayerId == %@", prayerId.uuidString)
        let query = CKQuery(recordType: RecordType.prayerPray, predicate: predicate)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 500)
            var count = 0

            for (_, result) in matchResults {
                switch result {
                case .success:
                    count += 1
                case .failure(let error):
                    print("⚠️ Failed to fetch prayer pray:", error.localizedDescription)
                }
            }

            return count
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ No PrayerPray record type exists yet in CloudKit. Returning zero.")
            return 0
        } catch {
            throw error
        }
    }

    func hasUserPrayed(for prayerId: UUID, userId: UUID) async throws -> Bool {
        let predicate = NSPredicate(
            format: "prayerId == %@ AND userId == %@",
            prayerId.uuidString,
            userId.uuidString
        )
        let query = CKQuery(recordType: RecordType.prayerPray, predicate: predicate)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            for (_, result) in matchResults {
                switch result {
                case .success:
                    return true
                case .failure:
                    continue
                }
            }

            return false
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return false
        } catch {
            throw error
        }
    }

    @discardableResult
    func savePrayerPray(
        prayerId: UUID,
        userId: UUID,
        userName: String,
        timestamp: Date = Date()
    ) async throws -> Int {
        let existing = try await hasUserPrayed(for: prayerId, userId: userId)
        if existing {
            return try await fetchPrayerPrayCount(for: prayerId)
        }

        let record = CKRecord(recordType: RecordType.prayerPray)
        record["prayerId"] = prayerId.uuidString as CKRecordValue
        record["userId"] = userId.uuidString as CKRecordValue
        record["userName"] = userName as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue

        _ = try await saveRecord(savedRecord: record)
        return try await fetchPrayerPrayCount(for: prayerId)
    }

    // MARK: - TESTIMONIES

    func fetchRecentTestimonies(limit: Int = 50) async throws -> [Testimony] {
        let query = CKQuery(
            recordType: RecordType.testimony,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: limit)

            var testimonies: [Testimony] = []

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let t = try? decodeTestimony(from: record) {
                        testimonies.append(t)
                    }
                case .failure(let error):
                    print("⚠️ Failed to fetch testimony record:", error.localizedDescription)
                }
            }

            return testimonies
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ No 'Testimony' record type exists yet in CloudKit. Returning empty list.")
            return []
        } catch {
            throw error
        }
    }

    func saveTestimony(_ testimony: Testimony) async throws -> Testimony {
        let recordID = testimonyRecordID(for: testimony)
        let record: CKRecord

        do {
            record = try await fetchRecord(with: recordID)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                record = CKRecord(recordType: RecordType.testimony, recordID: recordID)
            } else {
                throw error
            }
        }

        record["id"]         = testimony.id.uuidString as CKRecordValue
        record["authorName"] = testimony.authorName as CKRecordValue
        record["title"]      = testimony.title as CKRecordValue
        record["text"]       = testimony.text as CKRecordValue
        record["timestamp"]  = testimony.timestamp as CKRecordValue

        if let ownerId = testimony.ownerId {
            record["ownerId"] = ownerId.uuidString as CKRecordValue
        } else {
            record["ownerId"] = nil
        }

        if let linkedId = testimony.linkedPrayerId {
            record["linkedPrayerId"] = linkedId.uuidString as CKRecordValue
        } else {
            record["linkedPrayerId"] = nil
        }

        let saved = try await saveRecord(savedRecord: record)
        return try decodeTestimony(from: saved)
    }

    // MARK: - USERNAME SEARCH

    func searchProfiles(usernamePrefix: String) async throws -> [UserProfile] {
        let predicate = NSPredicate(format: "username BEGINSWITH %@", usernamePrefix)
        let query = CKQuery(recordType: RecordType.profile, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)]

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 25)

            var profiles: [UserProfile] = []

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let profile = try? userProfile(from: record) {
                        profiles.append(profile)
                    }
                case .failure(let error):
                    print("⚠️ Failed to fetch profile record:", error.localizedDescription)
                }
            }

            return profiles
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ No 'UserProfile' record type exists yet in CloudKit. Returning empty list.")
            return []
        } catch {
            throw error
        }
    }

    // MARK: - GLOBAL DIRECTORY SEARCH

    func searchUserProfiles(matching query: String, limit: Int = 50) async throws -> [DirectoryUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let searchText: String = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed

        var recordsByID: [CKRecord.ID: CKRecord] = [:]

        func runQuery(predicate: NSPredicate) async throws {
            let ckQuery = CKQuery(recordType: RecordType.profile, predicate: predicate)
            ckQuery.sortDescriptors = [
                NSSortDescriptor(key: "displayName", ascending: true),
                NSSortDescriptor(key: "username", ascending: true)
            ]

            do {
                let (matchResults, _) = try await publicDB.records(matching: ckQuery, resultsLimit: limit)

                for (_, result) in matchResults {
                    switch result {
                    case .success(let record):
                        recordsByID[record.recordID] = record
                    case .failure(let error):
                        print("⚠️ Failed to fetch profile record:", error.localizedDescription)
                    }
                }
            } catch let ckError as CKError where ckError.code == .unknownItem {
                print("ℹ️ No 'UserProfile' record type exists yet in CloudKit. Returning empty directory.")
            }
        }

        let usernamePredicate = NSPredicate(format: "username BEGINSWITH %@", searchText)
        try await runQuery(predicate: usernamePredicate)

        if recordsByID.count < limit {
            let namePredicate = NSPredicate(format: "displayName BEGINSWITH %@", searchText)
            try await runQuery(predicate: namePredicate)
        }

        let results: [DirectoryUser] = recordsByID.values.map { record in
            let displayName = record["displayName"] as? String ?? "New User"
            let username    = record["username"] as? String
            let bio         = record["bio"] as? String

            return DirectoryUser(
                id: record.recordID.recordName,
                displayName: displayName,
                username: username,
                bio: bio
            )
        }

        return results.sorted { lhs, rhs in
            if lhs.displayName == rhs.displayName {
                return (lhs.username ?? "") < (rhs.username ?? "")
            } else {
                return lhs.displayName < rhs.displayName
            }
        }
    }

    // MARK: - FETCH OTHER USER PROFILES

    func fetchProfile(displayName: String, username: String?) async throws -> UserProfile? {
        let trimmedUsername = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedUsername.isEmpty && trimmedUsername != "@username" {
            let usernamePredicate = NSPredicate(format: "username == %@", trimmedUsername)
            let usernameQuery = CKQuery(recordType: RecordType.profile, predicate: usernamePredicate)

            do {
                let (matchResults, _) = try await publicDB.records(matching: usernameQuery, resultsLimit: 1)

                for (_, result) in matchResults {
                    switch result {
                    case .success(let record):
                        return try userProfile(from: record)
                    case .failure:
                        continue
                    }
                }
            } catch let ckError as CKError where ckError.code == .unknownItem {
                print("ℹ️ No UserProfile found for username \(trimmedUsername). Trying displayName instead.")
            } catch {
                throw error
            }
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let namePredicate = NSPredicate(format: "displayName == %@", trimmedName)
        let nameQuery = CKQuery(recordType: RecordType.profile, predicate: namePredicate)

        do {
            let (matchResults, _) = try await publicDB.records(matching: nameQuery, resultsLimit: 1)

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    return try userProfile(from: record)
                case .failure:
                    continue
                }
            }

            return nil
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ No UserProfile found for displayName \(trimmedName).")
            return nil
        } catch {
            throw error
        }
    }

    // MARK: - USER STATS

    func fetchUserStats(forDisplayName displayName: String) async throws -> UserStats {
        let predicate = NSPredicate(format: "displayName == %@", displayName)
        let query = CKQuery(recordType: RecordType.profile, predicate: predicate)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            var foundRecord: CKRecord? = nil
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    foundRecord = record
                    break
                case .failure:
                    continue
                }
            }

            guard let record = foundRecord else {
                throw CKError(.unknownItem)
            }

            let followers       = record["followersCount"] as? Int ?? 0
            let prayersGiven    = record["prayersGiven"] as? Int ?? 0
            let prayersReceived = record["prayersReceived"] as? Int ?? 0

            return UserStats(
                id: record.recordID.recordName,
                followers: followers,
                prayersGiven: prayersGiven,
                prayersReceived: prayersReceived
            )
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ No UserProfile found for displayName \(displayName). Returning zeroed stats.")
            return UserStats(
                id: displayName,
                followers: 0,
                prayersGiven: 0,
                prayersReceived: 0
            )
        } catch {
            throw error
        }
    }

    // MARK: - Mapping Helpers

    private func userProfile(from record: CKRecord) throws -> UserProfile {
        let internalIdString = record["internalId"] as? String ?? UUID().uuidString
        let profileId = UUID(uuidString: internalIdString) ?? UUID()

        let displayName = record["displayName"] as? String ?? "New User"
        let username = record["username"] as? String ?? "@username"
        let age = record["age"] as? String ?? ""
        let location = record["location"] as? String ?? ""
        let bio = record["bio"] as? String ?? ""

        let primaryFocusString = record["primaryFocus"] as? String
        let primaryFocus = primaryFocusString.flatMap { PrayerCategory(rawValue: $0) }

        let prayersGiven = record["prayersGiven"] as? Int ?? 0
        let prayersReceived = record["prayersReceived"] as? Int ?? 0

        let savedStrings = record["savedPrayerIds"] as? [String] ?? []
        let prayedStrings = record["prayedPrayerIds"] as? [String] ?? []
        let unlockedBadgeStrings = record["unlockedBadgeIDs"] as? [String] ?? []

        let savedIds = Set(savedStrings.compactMap { UUID(uuidString: $0) })
        let prayedIds = Set(prayedStrings.compactMap { UUID(uuidString: $0) })
        let unlockedBadgeIDs = Set(unlockedBadgeStrings)

        let blockedStrings = record["blockedNames"] as? [String] ?? []
        let blockedNames = Set(blockedStrings)

        let partnerStrings = record["partners"] as? [String] ?? []
        let partners: [PrayerPartner] = partnerStrings.map { line in
            let parts = line.components(separatedBy: "||")
            let name = parts.first ?? ""
            let note = parts.count > 1 ? parts[1] : ""
            return PrayerPartner(name: name, note: note)
        }

        var imageData: Data? = nil
        if let asset = record["profileImage"] as? CKAsset,
           let fileURL = asset.fileURL {
            imageData = try? Data(contentsOf: fileURL)
        }

        return UserProfile(
            id: profileId,
            displayName: displayName,
            username: username,
            age: age,
            location: location,
            bio: bio,
            profileImageData: imageData,
            partners: partners,
            prayersGiven: prayersGiven,
            prayersReceived: prayersReceived,
            savedPrayerIds: savedIds,
            prayedPrayerIds: prayedIds,
            blockedNames: blockedNames,
            primaryFocus: primaryFocus,
            cloudKitRecordName: record.recordID.recordName,
            unlockedBadgeIDs: unlockedBadgeIDs
        )
    }

    private func decodePrayer(from record: CKRecord) throws -> PrayerRequest {
        let idString = record["id"] as? String ?? UUID().uuidString
        let id = UUID(uuidString: idString) ?? UUID()
        let authorName = record["authorName"] as? String ?? "Anonymous"
        let text = record["text"] as? String ?? ""
        let timestamp = record["timestamp"] as? Date ?? Date()
        let prayersCnt = record["prayersCount"] as? Int ?? 0

        var ownerId: UUID? = nil
        if let ownerStr = record["ownerId"] as? String {
            ownerId = UUID(uuidString: ownerStr)
        }

        let categoryStrings = record["categories"] as? [String] ?? []
        let categories: [PrayerCategory] = categoryStrings.compactMap { PrayerCategory(rawValue: $0) }

        let commentStrings = record["comments"] as? [String] ?? []
        let comments: [Comment] = commentStrings.compactMap { line in
            let parts = line.components(separatedBy: "||")
            guard parts.count >= 3 else { return nil }

            let author = parts[0]
            let text = parts[1]
            let tsNumber = TimeInterval(parts[2]) ?? Date().timeIntervalSince1970

            return Comment(
                prayerId: id.uuidString,
                authorName: author,
                authorUserId: ownerId ?? UUID(),
                text: text,
                timestamp: Date(timeIntervalSince1970: tsNumber)
            )
        }

        return PrayerRequest(
            id: id,
            authorName: authorName,
            text: text,
            timestamp: timestamp,
            prayersCount: prayersCnt,
            comments: comments,
            categories: categories,
            ownerId: ownerId
        )
    }

    private func decodeTestimony(from record: CKRecord) throws -> Testimony {
        let idString = record["id"] as? String ?? UUID().uuidString
        let id = UUID(uuidString: idString) ?? UUID()

        let authorName = record["authorName"] as? String ?? "Anonymous"
        let title = record["title"] as? String ?? ""
        let text = record["text"] as? String ?? ""
        let timestamp = record["timestamp"] as? Date ?? Date()

        var ownerId: UUID? = nil
        if let ownerStr = record["ownerId"] as? String {
            ownerId = UUID(uuidString: ownerStr)
        }

        var linkedPrayerId: UUID? = nil
        if let linkedStr = record["linkedPrayerId"] as? String {
            linkedPrayerId = UUID(uuidString: linkedStr)
        }

        return Testimony(
            id: id,
            authorName: authorName,
            title: title,
            text: text,
            timestamp: timestamp,
            ownerId: ownerId,
            linkedPrayerId: linkedPrayerId
        )
    }

    // MARK: - CK Convenience

    private func fetchRecord(with id: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            publicDB.fetch(withRecordID: id) { record, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let record = record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
        }
    }

    private func saveRecord(savedRecord record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            publicDB.save(record) { savedRecord, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let savedRecord = savedRecord {
                    continuation.resume(returning: savedRecord)
                } else {
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
        }
    }

    private func deleteRecord(with id: CKRecord.ID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            publicDB.delete(withRecordID: id) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func writeDataToTemporaryFile(data: Data, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }
}

// MARK: - App Notifications

extension CloudKitService {

    func sendAppNotification(
        recipientUserId: String,
        senderUserId: String,
        senderName: String,
        type: String,
        title: String,
        body: String,
        prayerId: UUID? = nil
    ) async throws {
        let trimmedRecipient = recipientUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSender = senderUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSenderName = senderName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedRecipient.isEmpty else { return }
        guard !trimmedSender.isEmpty else { return }
        guard !trimmedSenderName.isEmpty else { return }
        guard trimmedRecipient != trimmedSender else { return }

        print("📨 Creating AppNotification")
        print("   recipientUserId:", trimmedRecipient)
        print("   senderUserId:", trimmedSender)
        print("   type:", type)
        print("   title:", title)

        let record = CKRecord(recordType: RecordType.appNotification)
        record["recipientUserId"] = trimmedRecipient as CKRecordValue
        record["senderUserId"] = trimmedSender as CKRecordValue
        record["senderName"] = trimmedSenderName as CKRecordValue
        record["type"] = type as CKRecordValue
        record["title"] = title as CKRecordValue
        record["body"] = body as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        if let prayerId {
            record["prayerId"] = prayerId.uuidString as CKRecordValue
        }

        _ = try await saveRecord(savedRecord: record)
        print("✅ Sent AppNotification (\(type)) to \(trimmedRecipient)")
    }
}

// MARK: - CloudKit Notifications / Subscriptions

extension CloudKitService {

    func setupNotificationSubscriptionsForCurrentUser() async throws {
        let profile = try await fetchCurrentUserProfile()
        let myUserId = profile.id.uuidString
        let subscriptionID = "app_notifications_\(myUserId)"

        print("🔔 Starting AppNotification subscription setup")
        print("🔔 Current user id: \(myUserId)")
        print("🔔 Subscription ID: \(subscriptionID)")

        let predicate = NSPredicate(format: "recipientUserId == %@", myUserId)

        let subscription = CKQuerySubscription(
            recordType: RecordType.appNotification,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.titleLocalizationKey = "%1$@"
        info.titleLocalizationArgs = ["title"]
        info.alertLocalizationKey = "%1$@"
        info.alertLocalizationArgs = ["body"]
        info.soundName = "default"
        info.shouldBadge = true
        subscription.notificationInfo = info

        try await saveSubscription(subscription)
        print("✅ App notification subscription set up successfully")
        print("✅ Saved subscription: \(subscriptionID)")
    }

    private func saveSubscription(_ subscription: CKSubscription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifySubscriptionsOperation(
                subscriptionsToSave: [subscription],
                subscriptionIDsToDelete: []
            )

            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            self.publicDB.add(operation)
        }
    }
}

// MARK: - Delete Current User Data

extension CloudKitService {

    func deleteCurrentUserData() async throws {
        let userRecordID = try await container.userRecordID()
        let profileID = profileRecordID(forUserRecordID: userRecordID)

        var internalIdUUID: UUID? = nil
        if let profileRecord = try? await fetchRecord(with: profileID),
           let internalIdString = profileRecord["internalId"] as? String,
           let uuid = UUID(uuidString: internalIdString) {
            internalIdUUID = uuid
        }

        do {
            try await deleteRecord(with: profileID)
            print("✅ Deleted UserProfile record for current user")
        } catch let ckError as CKError where ckError.code == .unknownItem {
            print("ℹ️ No UserProfile to delete for current user (already removed).")
        } catch {
            throw error
        }

        guard let ownerUUID = internalIdUUID else {
            print("⚠️ No internalId on profile; skipping ownerId-based cleanup.")
            return
        }

        let ownerString = ownerUUID.uuidString

        func deleteAllMatching(recordType: String, predicate: NSPredicate) async throws {
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 400)

            for (recordID, result) in matchResults {
                switch result {
                case .success:
                    do {
                        try await deleteRecord(with: recordID)
                        print("🧹 Deleted \(recordType) record \(recordID.recordName)")
                    } catch let ckError as CKError where ckError.code == .unknownItem {
                        continue
                    } catch {
                        print("⚠️ Failed to delete \(recordType) \(recordID.recordName):", error)
                    }
                case .failure(let error):
                    print("⚠️ Failed to fetch \(recordType) for deletion:", error)
                }
            }
        }

        let prayersPredicate = NSPredicate(format: "ownerId == %@", ownerString)
        try await deleteAllMatching(recordType: RecordType.prayer, predicate: prayersPredicate)

        let testimoniesPredicate = NSPredicate(format: "ownerId == %@", ownerString)
        try await deleteAllMatching(recordType: RecordType.testimony, predicate: testimoniesPredicate)

        let notificationsPredicate = NSPredicate(format: "recipientUserId == %@ OR senderUserId == %@", ownerString, ownerString)
        try await deleteAllMatching(recordType: RecordType.appNotification, predicate: notificationsPredicate)

        let prayerCommentsPredicate = NSPredicate(format: "authorUserId == %@", ownerString)
        try await deleteAllMatching(recordType: RecordType.prayerComment, predicate: prayerCommentsPredicate)

        let prayerPraysPredicate = NSPredicate(format: "userId == %@", ownerString)
        try await deleteAllMatching(recordType: RecordType.prayerPray, predicate: prayerPraysPredicate)

        print("✅ Finished deleting current user's CloudKit data.")
    }
}
