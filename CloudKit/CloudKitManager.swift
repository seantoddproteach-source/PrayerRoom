//
//  CloudKitManager.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/16/25.
//

import Foundation
import CloudKit

// MARK: - CloudKit Record Types

enum CKRecordType {
    static let prayer = "PrayerRequest"
    static let testimony = "Testimony"
    static let userProfile = "UserProfile"
    static let publicUserProfile = "PublicUserProfile"   // 👈 public discovery
}

// MARK: - Public User Profile Model

struct PublicUserProfile: Identifiable {
    let id = UUID()
    let recordName: String
    let username: String
    let displayName: String
    let primaryFocus: PrayerCategory?
}

/// Handles all CloudKit read/write for prayers, testimonies, and user profile.
final class CloudKitManager {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    
    /// Use explicit container ID so we always talk to the right CloudKit container.
    /// Default is your production container: iCloud.com.SeanTodd.PrayerRoom
    init(container: CKContainer? = nil) {
        let containerID = "iCloud.com.SeanTodd.PrayerRoom"
        
        let resolvedContainer: CKContainer
        if let custom = container {
            resolvedContainer = custom
        } else {
            resolvedContainer = CKContainer(identifier: containerID)
        }
        
        self.container = resolvedContainer
        self.privateDatabase = resolvedContainer.privateCloudDatabase
        self.publicDatabase = resolvedContainer.publicCloudDatabase
        
        // 🔐 Log iCloud account status for this container once at startup
        Task {
            do {
                let status = try await resolvedContainer.accountStatus()
                print("🔐 CloudKitManager accountStatus for \(containerID): \(status.rawValue)")
            } catch {
                print("❌ CloudKitManager failed to fetch iCloud accountStatus:", error)
            }
        }
    }
    
    // MARK: - USER PROFILE (Private DB)
    
    /// Fetch the current user's profile from CloudKit (private DB).
    /// Returns `nil` if no profile record is found yet.
    func fetchUserProfile(completion: @escaping (Result<UserProfile?, Error>) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: CKRecordType.userProfile, predicate: predicate)
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 1
        
        var fetchedRecord: CKRecord?
        
        operation.recordMatchedBlock = { _, result in
            switch result {
            case .success(let record):
                fetchedRecord = record
            case .failure:
                break
            }
        }
        
        operation.queryResultBlock = { _ in
            if let record = fetchedRecord {
                let profile = self.userProfile(from: record)
                completion(.success(profile))
            } else {
                completion(.success(nil))
            }
        }
        
        operation.database = privateDatabase
        privateDatabase.add(operation)
    }
    
    /// Save or update the user's profile in private DB.
    /// Returns the recordName so PrayerStore can remember and reuse it.
    func saveUserProfile(_ profile: UserProfile, completion: ((Result<String, Error>) -> Void)? = nil) {
        let record = makeRecord(from: profile)
        
        privateDatabase.save(record) { saved, error in
            if let error = error {
                #if DEBUG
                print("❌ CloudKitManager.saveUserProfile error:", error)
                #endif
                completion?(.failure(error))
            } else if let saved = saved {
                #if DEBUG
                print("✅ CloudKitManager saved UserProfile:", saved.recordID.recordName)
                #endif
                completion?(.success(saved.recordID.recordName))
            } else {
                completion?(.failure(NSError(
                    domain: "CloudKitManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error saving profile"]
                )))
            }
        }
    }
    
    private func makeRecord(from profile: UserProfile) -> CKRecord {
        // cloudKitRecordName is a non-optional String now
        let recordID: CKRecord.ID
        if !profile.cloudKitRecordName.isEmpty {
            recordID = CKRecord.ID(recordName: profile.cloudKitRecordName)
        } else {
            recordID = CKRecord.ID(recordName: profile.id.uuidString)
        }
        
        let record = CKRecord(recordType: CKRecordType.userProfile, recordID: recordID)
        
        record["internalId"]      = profile.id.uuidString as CKRecordValue
        record["displayName"]     = profile.displayName as CKRecordValue
        record["username"]        = profile.username as CKRecordValue
        record["age"]             = profile.age as CKRecordValue
        record["location"]        = profile.location as CKRecordValue
        record["bio"]             = profile.bio as CKRecordValue
        record["prayersGiven"]    = profile.prayersGiven as CKRecordValue
        record["prayersReceived"] = profile.prayersReceived as CKRecordValue
        
        if let focus = profile.primaryFocus {
            record["primaryFocus"] = focus.rawValue as CKRecordValue
        } else {
            record["primaryFocus"] = nil
        }
        
        // Blocked names -> [String]
        let blockedArray = Array(profile.blockedNames)
        record["blockedNames"] = blockedArray as CKRecordValue
        
        // Profile image as CKAsset
        if let data = profile.profileImageData {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpg")
            do {
                try data.write(to: tempURL)
                let asset = CKAsset(fileURL: tempURL)
                record["profileImage"] = asset
            } catch {
                #if DEBUG
                print("⚠️ Failed to write image data for CKAsset:", error)
                #endif
            }
        } else {
            record["profileImage"] = nil
        }
        
        return record
    }
    
    private func userProfile(from record: CKRecord) -> UserProfile {
        let internalIdString = record["internalId"] as? String ?? UUID().uuidString
        let profileId = UUID(uuidString: internalIdString) ?? UUID()
        
        let displayName      = (record["displayName"] as? String) ?? "New User"
        let username         = (record["username"] as? String) ?? "@username"
        let age              = (record["age"] as? String) ?? ""
        let location         = (record["location"] as? String) ?? ""
        let bio              = (record["bio"] as? String) ?? "Child of God. Here to pray and encourage."
        let prayersGiven     = (record["prayersGiven"] as? Int) ?? 0
        let prayersReceived  = (record["prayersReceived"] as? Int) ?? 0
        
        // Primary focus
        var primaryFocus: PrayerCategory? = nil
        if let focusRaw = record["primaryFocus"] as? String {
            primaryFocus = PrayerCategory(rawValue: focusRaw)
        }
        
        // Blocked names
        let blockedStrings = record["blockedNames"] as? [String] ?? []
        let blockedNames   = Set(blockedStrings)
        
        // Image
        var imageData: Data? = nil
        if let asset = record["profileImage"] as? CKAsset,
           let url = asset.fileURL,
           let data = try? Data(contentsOf: url) {
            imageData = data
        }
        
        // Partners/saved/prayed not stored in this record → start empty
        let profile = UserProfile(
            id: profileId,
            displayName: displayName,
            username: username,
            age: age,
            location: location,
            bio: bio,
            profileImageData: imageData,
            partners: [],
            prayersGiven: prayersGiven,
            prayersReceived: prayersReceived,
            savedPrayerIds: [],
            prayedPrayerIds: [],
            blockedNames: blockedNames,
            primaryFocus: primaryFocus,
            cloudKitRecordName: record.recordID.recordName
        )
        
        return profile
    }
    
    // MARK: - PUBLIC USER PROFILE (Public DB)
    
    /// Upsert a public profile so others can discover by @username.
    func upsertPublicUserProfile(from profile: UserProfile, completion: ((Result<String, Error>) -> Void)? = nil) {
        // Don't publish if username is empty / default
        let rawUsername = profile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawUsername.isEmpty, rawUsername != "@username" else {
            completion?(.success("skipped"))
            return
        }
        
        let normalized = rawUsername.lowercased()
        
        // 1) Look for an existing public profile with this usernameLower
        let predicate = NSPredicate(format: "usernameLower == %@", normalized)
        let query = CKQuery(recordType: CKRecordType.publicUserProfile, predicate: predicate)
        
        publicDatabase.perform(query, inZoneWith: nil) { [weak self] records, error in
            if let error = error {
                completion?(.failure(error))
                return
            }
            
            let record: CKRecord
            if let existing = records?.first {
                record = existing
            } else {
                let recordID = CKRecord.ID(recordName: UUID().uuidString)
                record = CKRecord(recordType: CKRecordType.publicUserProfile, recordID: recordID)
            }
            
            record["username"]      = rawUsername as CKRecordValue
            record["usernameLower"] = normalized as CKRecordValue
            record["displayName"]   = profile.displayName as CKRecordValue
            
            if let focus = profile.primaryFocus {
                record["primaryFocus"] = focus.rawValue as CKRecordValue
            } else {
                record["primaryFocus"] = nil
            }
            
            self?.publicDatabase.save(record) { saved, saveError in
                if let saveError = saveError {
                    completion?(.failure(saveError))
                } else if let saved = saved {
                    completion?(.success(saved.recordID.recordName))
                } else {
                    completion?(.failure(NSError(
                        domain: "CloudKitManager",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error saving public user profile"]
                    )))
                }
            }
        }
    }
    
    /// Search public profiles by username prefix (case-insensitive).
    func searchPublicProfiles(usernamePrefix: String, limit: Int = 10, completion: @escaping (Result<[PublicUserProfile], Error>) -> Void) {
        let trimmed = usernamePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success([]))
            return
        }
        
        let normalized = trimmed.lowercased()
        let predicate = NSPredicate(format: "usernameLower BEGINSWITH %@", normalized)
        let query = CKQuery(recordType: CKRecordType.publicUserProfile, predicate: predicate)
        let sort = NSSortDescriptor(key: "usernameLower", ascending: true)
        query.sortDescriptors = [sort]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit
        
        var results: [PublicUserProfile] = []
        
        operation.recordMatchedBlock = { _, result in
            switch result {
            case .success(let record):
                let username = (record["username"] as? String) ?? ""
                let displayName = (record["displayName"] as? String) ?? ""
                var focus: PrayerCategory? = nil
                if let focusRaw = record["primaryFocus"] as? String {
                    focus = PrayerCategory(rawValue: focusRaw)
                }
                
                let model = PublicUserProfile(
                    recordName: record.recordID.recordName,
                    username: username,
                    displayName: displayName,
                    primaryFocus: focus
                )
                results.append(model)
            case .failure:
                break
            }
        }
        
        operation.queryResultBlock = { _ in
            completion(.success(results))
        }
        
        operation.database = publicDatabase
        publicDatabase.add(operation)
    }
    
    // MARK: - PRAYERS (Private DB)
    
    func fetchPrayers(completion: @escaping (Result<[PrayerRequest], Error>) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: CKRecordType.prayer, predicate: predicate)
        let sort = NSSortDescriptor(key: "timestamp", ascending: false)
        query.sortDescriptors = [sort]
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let result = (records ?? []).compactMap { self.prayer(from: $0) }
            completion(.success(result))
        }
    }
    
    func savePrayer(_ prayer: PrayerRequest, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let record = makeRecord(from: prayer)
        
        privateDatabase.save(record) { _, error in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }
    
    // MARK: - TESTIMONIES (Private DB)
    
    func fetchTestimonies(completion: @escaping (Result<[Testimony], Error>) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: CKRecordType.testimony, predicate: predicate)
        let sort = NSSortDescriptor(key: "timestamp", ascending: false)
        query.sortDescriptors = [sort]
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let result = (records ?? []).compactMap { self.testimony(from: $0) }
            completion(.success(result))
        }
    }
    
    func saveTestimony(_ testimony: Testimony, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let record = makeRecord(from: testimony)
        
        privateDatabase.save(record) { _, error in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }
    
    // MARK: - Mapping: PrayerRequest <-> CKRecord
    
    private func makeRecord(from prayer: PrayerRequest) -> CKRecord {
        let recordID = CKRecord.ID(recordName: prayer.id.uuidString)
        let record = CKRecord(recordType: CKRecordType.prayer, recordID: recordID)
        
        record["text"]         = prayer.text as CKRecordValue
        record["authorName"]   = prayer.authorName as CKRecordValue
        record["timestamp"]    = prayer.timestamp as CKRecordValue
        record["prayersCount"] = prayer.prayersCount as CKRecordValue
        
        let categoryStrings = prayer.categories.map { $0.rawValue }
        record["categories"] = categoryStrings as CKRecordValue
        
        if let ownerId = prayer.ownerId {
            record["ownerId"] = ownerId.uuidString as CKRecordValue
        } else {
            record["ownerId"] = nil
        }
        
        return record
    }
    
    private func prayer(from record: CKRecord) -> PrayerRequest? {
        guard
            let text = record["text"] as? String,
            let authorName = record["authorName"] as? String
        else {
            return nil
        }
        
        let categoryStrings = record["categories"] as? [String] ?? []
        let categories: [PrayerCategory] = categoryStrings.compactMap { PrayerCategory(rawValue: $0) }
        
        let ownerIdString = record["ownerId"] as? String
        let ownerId = ownerIdString.flatMap { UUID(uuidString: $0) }
        
        var prayer = PrayerRequest(
            authorName: authorName,
            text: text,
            categories: categories.isEmpty ? [.other] : categories,
            ownerId: ownerId
        )
        
        if let timestamp = record["timestamp"] as? Date {
            prayer.timestamp = timestamp
        }
        if let count = record["prayersCount"] as? Int {
            prayer.prayersCount = count
        }
        
        return prayer
    }
    
    // MARK: - Mapping: Testimony <-> CKRecord
    
    private func makeRecord(from testimony: Testimony) -> CKRecord {
        let recordID = CKRecord.ID(recordName: testimony.id.uuidString)
        let record = CKRecord(recordType: CKRecordType.testimony, recordID: recordID)
        
        record["title"]      = testimony.title as CKRecordValue
        record["text"]       = testimony.text as CKRecordValue
        record["authorName"] = testimony.authorName as CKRecordValue
        record["timestamp"]  = testimony.timestamp as CKRecordValue
        
        if let ownerId = testimony.ownerId {
            record["ownerId"] = ownerId.uuidString as CKRecordValue
        } else {
            record["ownerId"] = nil
        }
        
        return record
    }
    
    private func testimony(from record: CKRecord) -> Testimony? {
        guard
            let title = record["title"] as? String,
            let text = record["text"] as? String,
            let authorName = record["authorName"] as? String
        else {
            return nil
        }
        
        let ownerIdString = record["ownerId"] as? String
        let ownerId = ownerIdString.flatMap { UUID(uuidString: $0) }
        
        var testimony = Testimony(
            authorName: authorName,
            title: title,
            text: text,
            ownerId: ownerId
        )
        
        if let timestamp = record["timestamp"] as? Date {
            testimony.timestamp = timestamp
        }
        
        return testimony
    }
}
