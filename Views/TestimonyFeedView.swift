//
//  TestimonyFeedView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/13/25.
//

import SwiftUI
import UIKit

// MARK: - Local Proclaim Meter Model (view-only)

struct ProclaimMeterData {
    let level: Int
    let title: String
    let description: String
    let currentPoints: Int
    let pointsForNext: Int
    let progress: Double   // 0.0 ... 1.0
}

// MARK: - Testimony Feed (Proclaim)

struct TestimonyFeedView: View {
    @EnvironmentObject var store: PrayerStore
    @State private var showingComposer = false
    @State private var editingTestimony: Testimony? = nil

    @State private var testimonyBeingReported: Testimony? = nil
    @State private var testimonyAuthorBeingReported: String? = nil
    @State private var showingTestimonyReportDialog = false
    @State private var showingTestimonyAuthorReportDialog = false
    @State private var showingReportSentAlert = false
    @State private var reportSentMessage = ""

    private var sortedTestimonies: [Testimony] {
        store.testimonies.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        let meter = buildProclaimMeter(from: store)

        return NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Proclaim")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Spacer()

                        Button {
                            showingComposer = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
                                Text("New Testimony")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.20))
                            .foregroundColor(.white)
                            .cornerRadius(999)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    proclaimMeterCard(meter: meter)
                        .padding(.horizontal)

                    ScrollView {
                        if sortedTestimonies.isEmpty {
                            VStack(spacing: 10) {
                                Spacer(minLength: 40)
                                Text("No testimonies yet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(PrayerTheme.textPrimary)
                                Text("When prayers are answered, share your story here to encourage others.")
                                    .font(.system(size: 13))
                                    .foregroundColor(PrayerTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Spacer(minLength: 40)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                            .padding(.vertical, 24)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(sortedTestimonies) { testimony in
                                    let isOwner: Bool = {
                                        if let ownerId = testimony.ownerId {
                                            return ownerId == store.profile.id
                                        } else {
                                            return testimony.authorName
                                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                                .caseInsensitiveCompare(store.effectiveAuthorName) == .orderedSame
                                        }
                                    }()

                                    TestimonyRowView(
                                        testimony: testimony,
                                        isOwner: isOwner,
                                        onEdit: {
                                            if isOwner {
                                                editingTestimony = testimony
                                            }
                                        },
                                        onReportTestimony: {
                                            testimonyBeingReported = testimony
                                            showingTestimonyReportDialog = true
                                        },
                                        onReportUser: {
                                            testimonyAuthorBeingReported = testimony.authorName
                                            showingTestimonyAuthorReportDialog = true
                                        },
                                        onBlockUser: {
                                            store.blockUser(name: testimony.authorName)
                                            reportSentMessage = "\(testimony.authorName) has been blocked."
                                            showingReportSentAlert = true
                                        }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if isOwner {
                                            Button(role: .destructive) {
                                                deleteTestimony(testimony)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                        }
                    }
                    .refreshable {
                        await store.refreshTestimonies()
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                NewTestimonyComposerView(store: store, linkedPrayerId: nil)
            }
            .sheet(item: $editingTestimony) { testimony in
                EditTestimonyView(store: store, testimony: testimony)
            }
            .sheet(item: $store.newlyUnlockedBadge) { badge in
                ZStack {
                    PrayerTheme.gradient
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Image(systemName: badge.systemImage)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)

                        Text("Badge Unlocked!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)

                        Text(badge.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Text(badge.subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            store.newlyUnlockedBadge = nil
                        } label: {
                            Text("Awesome")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }
                    .padding(24)
                }
            }
            .confirmationDialog("Report Testimony", isPresented: $showingTestimonyReportDialog, titleVisibility: .visible) {
                if let testimony = testimonyBeingReported {
                    Button("Offensive language") {
                        reportTestimony(testimony, reason: "Offensive language")
                    }
                    Button("Harassment") {
                        reportTestimony(testimony, reason: "Harassment")
                    }
                    Button("Spam") {
                        reportTestimony(testimony, reason: "Spam")
                    }
                    Button("False or misleading content") {
                        reportTestimony(testimony, reason: "False or misleading content")
                    }
                    Button("Other") {
                        reportTestimony(testimony, reason: "Other")
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Report User", isPresented: $showingTestimonyAuthorReportDialog, titleVisibility: .visible) {
                if let name = testimonyAuthorBeingReported {
                    Button("Harassment") {
                        reportUser(named: name, reason: "Harassment")
                    }
                    Button("Spam") {
                        reportUser(named: name, reason: "Spam")
                    }
                    Button("Inappropriate behavior") {
                        reportUser(named: name, reason: "Inappropriate behavior")
                    }
                    Button("Other") {
                        reportUser(named: name, reason: "Other")
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Report Submitted", isPresented: $showingReportSentAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(reportSentMessage)
            }
        }
    }

    // MARK: - Build Proclaim Meter from store

    private func buildProclaimMeter(from store: PrayerStore) -> ProclaimMeterData {
        let myId = store.profile.id

        let myTestimonies = store.testimonies.filter { testimony in
            if let ownerId = testimony.ownerId {
                return ownerId == myId
            } else {
                return testimony.authorName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(store.effectiveAuthorName) == .orderedSame
            }
        }

        let testimonyPoints       = myTestimonies.count * 5
        let prayersGivenPoints    = store.profile.prayersGiven
        let prayersReceivedPoints = store.profile.prayersReceived

        let totalPoints = testimonyPoints + prayersGivenPoints + prayersReceivedPoints

        struct LevelConfig {
            let minPoints: Int
            let title: String
            let description: String
        }

        let levels: [LevelConfig] = [
            LevelConfig(minPoints: 0,   title: "Getting Started", description: "Share your first story of what God has done."),
            LevelConfig(minPoints: 25,  title: "Faithful Voice",  description: "You’re starting to regularly share prayers and testimonies."),
            LevelConfig(minPoints: 75,  title: "Bold Witness",    description: "Your stories are strengthening others in their faith."),
            LevelConfig(minPoints: 150, title: "Beacon of Hope",  description: "You consistently proclaim God’s goodness in this community.")
        ]

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

        let nextLevelMinPoints: Int
        if currentLevelIndex < levels.count - 1 {
            nextLevelMinPoints = levels[currentLevelIndex + 1].minPoints
        } else {
            nextLevelMinPoints = currentLevel.minPoints + 100
        }

        let pointsIntoThisLevel   = max(0, totalPoints - currentLevel.minPoints)
        let pointsNeededThisLevel = max(1, nextLevelMinPoints - currentLevel.minPoints)
        let progress = Double(pointsIntoThisLevel) / Double(pointsNeededThisLevel)

        return ProclaimMeterData(
            level: currentLevelIndex + 1,
            title: currentLevel.title,
            description: currentLevel.description,
            currentPoints: totalPoints,
            pointsForNext: nextLevelMinPoints,
            progress: min(max(progress, 0.0), 1.0)
        )
    }

    // MARK: - Proclaim Meter Card

    private func proclaimMeterCard(meter: ProclaimMeterData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Proclaim Meter")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("Lv \(meter.level)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [PrayerTheme.accent, PrayerTheme.highlight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(999)
            }

            Text(meter.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PrayerTheme.textPrimary)

            Text(meter.description)
                .font(.system(size: 11))
                .foregroundColor(PrayerTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 8)

                    GeometryReader { geo in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [PrayerTheme.accent, PrayerTheme.highlight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(8, geo.size.width * CGFloat(meter.progress)),
                                height: 8
                            )
                    }
                    .frame(height: 8)
                }

                HStack {
                    Text("\(meter.currentPoints) pts")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Next at \(meter.pointsForNext) pts")
                        .font(.system(size: 10))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func deleteTestimony(_ testimony: Testimony) {
        store.deleteTestimony(testimony)
    }

    private func reportTestimony(_ testimony: Testimony, reason: String) {
        store.reportContent(
            contentType: "testimony",
            contentId: testimony.id.uuidString,
            reason: reason
        )
        testimonyBeingReported = nil
        reportSentMessage = "Thanks for reporting this testimony. We’ll review it."
        showingReportSentAlert = true
    }

    private func reportUser(named name: String, reason: String) {
        store.reportContent(
            contentType: "user",
            contentId: name,
            reason: reason
        )
        testimonyAuthorBeingReported = nil
        reportSentMessage = "Thanks for reporting this user. We’ll review it."
        showingReportSentAlert = true
    }
}

// MARK: - Testimony Row

struct TestimonyRowView: View {
    @EnvironmentObject var store: PrayerStore
    let testimony: Testimony
    let isOwner: Bool
    var onEdit: () -> Void
    var onReportTestimony: () -> Void
    var onReportUser: () -> Void
    var onBlockUser: () -> Void

    @State private var remoteProfile: UserProfile? = nil
    @State private var didLoadProfile = false

    private var displayNameTrimmed: String {
        testimony.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var avatarView: some View {
        if isOwner,
           let data = store.profile.profileImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [PrayerTheme.accent, PrayerTheme.highlight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        } else if let data = remoteProfile?.profileImageData,
                  let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [PrayerTheme.accent, PrayerTheme.highlight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PrayerTheme.accent, PrayerTheme.highlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)

                Text(String(displayNameTrimmed.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                avatarView

                VStack(alignment: .leading, spacing: 2) {
                    Text(testimony.authorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PrayerTheme.textPrimary)

                    Text(testimony.timestamp, style: .date)
                        .font(.system(size: 11))
                        .foregroundColor(PrayerTheme.textSecondary)
                }

                Spacer()

                if isOwner {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 44, minHeight: 44, alignment: .center)
                        .background(Color.white.opacity(0.10))
                        .foregroundColor(.white)
                        .cornerRadius(999)
                    }
                    .buttonStyle(.plain)
                } else {
                    Menu {
                        Button {
                            onReportTestimony()
                        } label: {
                            Label("Report Testimony", systemImage: "exclamationmark.bubble")
                        }

                        Button {
                            onReportUser()
                        } label: {
                            Label("Report User", systemImage: "person.crop.circle.badge.exclam")
                        }

                        Button(role: .destructive) {
                            onBlockUser()
                        } label: {
                            Label("Block User", systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(PrayerTheme.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(testimony.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(PrayerTheme.textPrimary)

            Text(testimony.text)
                .font(.system(size: 14))
                .foregroundColor(PrayerTheme.textPrimary)
                .multilineTextAlignment(.leading)

            if let linkedId = testimony.linkedPrayerId {
                HStack {
                    NavigationLink {
                        PrayerDetailView(prayerId: linkedId)
                    } label: {
                        Label("From a prayer story", systemImage: "link")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(999)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .prayerCard()
        .task {
            guard !isOwner else { return }
            guard !didLoadProfile else { return }
            didLoadProfile = true

            let trimmedName = displayNameTrimmed
            guard !trimmedName.isEmpty else { return }

            if let fetched = await store.loadRemoteProfileForPerson(displayName: trimmedName, username: nil) {
                self.remoteProfile = fetched
            }
        }
    }
}

// MARK: - New Testimony Composer

struct NewTestimonyComposerView: View {
    let store: PrayerStore
    @Environment(\.dismiss) private var dismiss

    let linkedPrayerId: UUID?

    init(store: PrayerStore, linkedPrayerId: UUID? = nil) {
        self.store = store
        self.linkedPrayerId = linkedPrayerId
    }

    @State private var title: String = ""
    @State private var text: String = ""
    @State private var moderationMessage: String = ""
    @State private var showingModerationAlert = false

    private var postingName: String {
        let profileName = store.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty && profileName != "New User" { return profileName }

        let appleName = UserDefaults.standard.string(forKey: "appleFullName")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !appleName.isEmpty { return appleName }

        return "Anonymous"
    }

    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(linkedPrayerId == nil ? "Share a Testimony" : "Share an Update")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)

                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 14))
                                Text("Posting as ")
                                    .font(.system(size: 13))
                                    .foregroundColor(PrayerTheme.textSecondary)
                                Text(postingName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)

                            TextField("Title (e.g. Job Answered, Healing, Breakthrough)", text: $title)
                                .textFieldStyle(.roundedBorder)

                            ZStack(alignment: .topLeading) {
                                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(
                                        linkedPrayerId == nil
                                        ? "How did God answer? Share the story to encourage others."
                                        : "Share how God is moving in this prayer story."
                                    )
                                    .foregroundColor(Color.secondary.opacity(0.7))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 6)
                                }

                                TextEditor(text: $text)
                                    .frame(minHeight: 160)
                                    .scrollContentBackground(.hidden)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                        .prayerCard()
                        .padding(.horizontal)
                        .padding(.top, 12)

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { submitTestimony() }
                        .foregroundColor(.white)
                        .disabled(!canPost)
                }
            }
            .alert("Unable to Post", isPresented: $showingModerationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(moderationMessage)
            }
        }
    }

    private func submitTestimony() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText  = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedText.isEmpty else { return }

        let moderation = ModerationService.moderate("\(trimmedTitle) \(trimmedText)")

        switch moderation {
        case .clean:
            break
        case .flagged(let reason):
            print("⚠️ Testimony flagged:", reason)
        case .blocked(let reason):
            moderationMessage = reason
            showingModerationAlert = true
            print("❌ Testimony blocked:", reason)
            return
        }

        if let linkedPrayerId {
            guard let prayer = store.prayer(withId: linkedPrayerId) else {
                print("❌ Cannot post update: linked prayer not found")
                return
            }

            let isOwner: Bool
            if let ownerId = prayer.ownerId {
                isOwner = ownerId == store.profile.id
            } else {
                isOwner = prayer.authorName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(store.effectiveAuthorName) == .orderedSame
            }

            guard isOwner else {
                print("❌ Cannot post update to another user's prayer")
                return
            }
        }

        let newTestimony = Testimony(
            authorName: postingName,
            title: trimmedTitle,
            text: trimmedText,
            timestamp: Date(),
            ownerId: store.profile.id,
            linkedPrayerId: linkedPrayerId
        )

        store.testimonies.insert(newTestimony, at: 0)

        Task { @MainActor in
            do {
                let saved = try await store.cloud.saveTestimony(newTestimony)
                if let idx = store.testimonies.firstIndex(where: { $0.id == newTestimony.id }) {
                    store.testimonies[idx] = saved
                }
                store.checkForNewBadges()
                dismiss()
            } catch {
                print("❌ Failed to save new testimony to CloudKit:", error)
                if let idx = store.testimonies.firstIndex(where: { $0.id == newTestimony.id }) {
                    store.testimonies.remove(at: idx)
                }
            }
        }
    }
}

// MARK: - Edit Testimony View

struct EditTestimonyView: View {
    let store: PrayerStore
    @Environment(\.dismiss) private var dismiss

    let testimonyId: UUID
    @State private var title: String
    @State private var text: String
    @State private var moderationMessage: String = ""
    @State private var showingModerationAlert = false

    init(store: PrayerStore, testimony: Testimony) {
        self.store = store
        self.testimonyId = testimony.id
        _title = State(initialValue: testimony.title)
        _text  = State(initialValue: testimony.text)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Edit Testimony")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)

                            TextField("Title", text: $title)
                                .textFieldStyle(.roundedBorder)

                            ZStack(alignment: .topLeading) {
                                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Update the story of what God did.")
                                        .foregroundColor(Color.secondary.opacity(0.7))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 6)
                                }
                                TextEditor(text: $text)
                                    .frame(minHeight: 160)
                                    .scrollContentBackground(.hidden)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                        .prayerCard()
                        .padding(.horizontal)
                        .padding(.top, 12)

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .foregroundColor(.white)
                        .disabled(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }

                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        deleteTestimony()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Testimony")
                        }
                    }
                }
            }
            .alert("Unable to Save", isPresented: $showingModerationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(moderationMessage)
            }
        }
    }

    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText  = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedText.isEmpty else { return }

        let moderation = ModerationService.moderate("\(trimmedTitle) \(trimmedText)")

        switch moderation {
        case .clean:
            break
        case .flagged(let reason):
            print("⚠️ Edited testimony flagged:", reason)
        case .blocked(let reason):
            moderationMessage = reason
            showingModerationAlert = true
            print("❌ Edited testimony blocked:", reason)
            return
        }

        guard let testimony = store.testimonies.first(where: { $0.id == testimonyId }) else {
            dismiss()
            return
        }

        store.editTestimony(testimony, newTitle: trimmedTitle, newText: trimmedText)
        dismiss()
    }

    private func deleteTestimony() {
        if let testimony = store.testimonies.first(where: { $0.id == testimonyId }) {
            store.deleteTestimony(testimony)
        }
        dismiss()
    }
}
