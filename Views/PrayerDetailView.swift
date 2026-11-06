//
//  PrayerDetailView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/13/25.
//

import SwiftUI
import UIKit

struct PrayerDetailView: View {
    @EnvironmentObject var store: PrayerStore
    let prayerId: UUID

    @State private var commentText: String = ""
    @State private var showingStoryComposer = false
    @State private var showingEdit = false

    @State private var showingEditCommentSheet = false
    @State private var commentBeingEdited: Comment? = nil
    @State private var editedCommentText: String = ""

    @State private var showingDeleteCommentAlert = false
    @State private var commentBeingDeleted: Comment? = nil

    @State private var showingEditStorySheet = false
    @State private var storyBeingEdited: Testimony? = nil
    @State private var editedStoryTitle: String = ""
    @State private var editedStoryText: String = ""

    @State private var showingDeleteStoryAlert = false
    @State private var storyBeingDeleted: Testimony? = nil

    @State private var remotePrayerAuthorProfile: UserProfile? = nil
    @State private var didLoadPrayerAuthorProfile = false

    @State private var showingPrayerReportDialog = false
    @State private var showingUserReportDialog = false
    @State private var prayerReportTarget: PrayerRequest? = nil

    @State private var showingCommentReportDialog = false
    @State private var commentBeingReported: Comment? = nil

    @State private var showingCommentAuthorReportDialog = false
    @State private var commentAuthorNameBeingReported: String? = nil

    @State private var showingReportSentAlert = false
    @State private var reportSentMessage = ""

    @State private var showingPostPrayerSharePrompt = false
    @State private var sharePrayerText = ""

    private var prayer: PrayerRequest? {
        store.prayer(withId: prayerId)
    }

    private var storyTestimonies: [Testimony] {
        store.testimonies
            .filter { $0.linkedPrayerId == prayerId }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func isOwner(_ prayer: PrayerRequest) -> Bool {
        if let ownerId = prayer.ownerId {
            return ownerId == store.profile.id
        } else {
            return prayer.authorName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(store.effectiveAuthorName) == .orderedSame
        }
    }

    private func isFollowingAuthor(_ prayer: PrayerRequest) -> Bool {
        store.profile.partners.contains { partner in
            partner.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(
                    prayer.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
                ) == .orderedSame
        }
    }

    private func isBlockedAuthor(_ prayer: PrayerRequest) -> Bool {
        let trimmedAuthor = prayer.authorName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return store.profile.blockedNames.contains { blocked in
            blocked.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmedAuthor) == .orderedSame
        }
    }

    private func isMyComment(_ comment: Comment) -> Bool {
        comment.authorUserId == store.profile.id
    }

    private func isMyStoryUpdate(_ testimony: Testimony) -> Bool {
        testimony.ownerId == store.profile.id
    }

    private var prayerAuthorImageData: Data? {
        guard let prayer = prayer else { return nil }
        return isOwner(prayer) ? store.profile.profileImageData : remotePrayerAuthorProfile?.profileImageData
    }

    @ViewBuilder
    private func prayerAuthorAvatar(for prayer: PrayerRequest) -> some View {
        if let data = prayerAuthorImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)

                Text(String(prayer.authorName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    var body: some View {
        mainContent
    }

    private var mainContent: some View {
        ZStack {
            PrayerTheme.gradient
                .ignoresSafeArea()

            if let prayer = prayer {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            headerCard(for: prayer)
                            contentCard(for: prayer)
                            updatesSection(for: prayer)
                            commentsSection(for: prayer)
                        }
                        .padding()
                    }

                    commentComposer(for: prayer)
                        .background(.ultraThinMaterial)
                }
            } else {
                Text("Prayer not found")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PrayerTheme.textPrimary)
            }
        }
        .navigationTitle("Prayer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { prayerToolbar }
        .task(id: prayerId) {
            await loadPrayerAuthorProfile()
        }
        .sheet(isPresented: $showingStoryComposer) {
            NewTestimonyComposerView(
                store: store,
                linkedPrayerId: prayerId
            )
        }
        .sheet(isPresented: $showingEdit) {
            if let prayer = prayer {
                PrayerEditView(prayer: prayer)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showingEditCommentSheet) {
            editCommentSheet
        }
        .sheet(isPresented: $showingEditStorySheet) {
            editStorySheet
        }
        .confirmationDialog(
            "Report Prayer",
            isPresented: $showingPrayerReportDialog,
            titleVisibility: .visible
        ) {
            prayerReportDialogButtons
        }
        .confirmationDialog(
            "Report User",
            isPresented: $showingUserReportDialog,
            titleVisibility: .visible
        ) {
            prayerUserReportDialogButtons
        }
        .confirmationDialog(
            "Report Comment",
            isPresented: $showingCommentReportDialog,
            titleVisibility: .visible
        ) {
            commentReportDialogButtons
        }
        .confirmationDialog(
            "Report User",
            isPresented: $showingCommentAuthorReportDialog,
            titleVisibility: .visible
        ) {
            commentUserReportDialogButtons
        }
        .confirmationDialog(
            "Invite someone to pray too",
            isPresented: $showingPostPrayerSharePrompt,
            titleVisibility: .visible
        ) {
            postPrayerShareButtons
        } message: {
            Text("You just prayed for this request. Invite someone else to join you.")
        }
        .alert("Delete Comment?", isPresented: $showingDeleteCommentAlert) {
            deleteCommentAlertButtons
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Delete Update?", isPresented: $showingDeleteStoryAlert) {
            deleteUpdateAlertButtons
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Report Submitted", isPresented: $showingReportSentAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(reportSentMessage)
        }
    }

    @ToolbarContentBuilder
    private var prayerToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if let prayer = prayer, isOwner(prayer) {
                Button {
                    showingEdit = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                }
            }
        }
    }

    private func loadPrayerAuthorProfile() async {
        didLoadPrayerAuthorProfile = false
        remotePrayerAuthorProfile = nil

        guard let prayer = prayer else { return }
        guard !isOwner(prayer) else { return }
        guard !didLoadPrayerAuthorProfile else { return }

        didLoadPrayerAuthorProfile = true

        let trimmedName = prayer.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        remotePrayerAuthorProfile = await store.loadRemoteProfileForPerson(
            displayName: trimmedName,
            username: nil
        )
    }

    private var editCommentSheet: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Edit Comment")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(PrayerTheme.textPrimary)

                        ZStack(alignment: .topLeading) {
                            if editedCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Update your comment...")
                                    .foregroundColor(Color.secondary.opacity(0.7))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 6)
                            }

                            TextEditor(text: $editedCommentText)
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .prayerCard()
                    .padding()

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEditCommentSheet = false
                        commentBeingEdited = nil
                        editedCommentText = ""
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEditedComment()
                    }
                    .foregroundColor(.white)
                    .disabled(editedCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var editStorySheet: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Edit Update")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(PrayerTheme.textPrimary)

                        TextField("Title (optional)", text: $editedStoryTitle)
                            .textFieldStyle(.roundedBorder)

                        ZStack(alignment: .topLeading) {
                            if editedStoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Update your story...")
                                    .foregroundColor(Color.secondary.opacity(0.7))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 6)
                            }

                            TextEditor(text: $editedStoryText)
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .prayerCard()
                    .padding()

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEditStorySheet = false
                        storyBeingEdited = nil
                        editedStoryTitle = ""
                        editedStoryText = ""
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEditedStoryUpdate()
                    }
                    .foregroundColor(.white)
                    .disabled(editedStoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var prayerReportDialogButtons: some View {
        if let prayer = prayerReportTarget {
            Button("Offensive language") {
                reportPrayer(prayer, reason: "Offensive language")
            }
            Button("Harassment") {
                reportPrayer(prayer, reason: "Harassment")
            }
            Button("Spam") {
                reportPrayer(prayer, reason: "Spam")
            }
            Button("False or misleading content") {
                reportPrayer(prayer, reason: "False or misleading content")
            }
            Button("Other") {
                reportPrayer(prayer, reason: "Other")
            }
        }
        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var prayerUserReportDialogButtons: some View {
        if let prayer = prayerReportTarget {
            Button("Harassment") {
                reportUser(named: prayer.authorName, reason: "Harassment")
            }
            Button("Spam") {
                reportUser(named: prayer.authorName, reason: "Spam")
            }
            Button("Inappropriate behavior") {
                reportUser(named: prayer.authorName, reason: "Inappropriate behavior")
            }
            Button("Other") {
                reportUser(named: prayer.authorName, reason: "Other")
            }
        }
        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var commentReportDialogButtons: some View {
        if let comment = commentBeingReported {
            Button("Offensive language") {
                reportComment(comment, reason: "Offensive language")
            }
            Button("Harassment") {
                reportComment(comment, reason: "Harassment")
            }
            Button("Spam") {
                reportComment(comment, reason: "Spam")
            }
            Button("False or misleading content") {
                reportComment(comment, reason: "False or misleading content")
            }
            Button("Other") {
                reportComment(comment, reason: "Other")
            }
        }
        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var commentUserReportDialogButtons: some View {
        if let name = commentAuthorNameBeingReported {
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

    @ViewBuilder
    private var postPrayerShareButtons: some View {
        ShareLink(
            item: sharePrayerText,
            subject: Text("Pray with me"),
            message: Text("Join me in prayer in The Prayer Room")
        ) {
            Label("Share Prayer", systemImage: "square.and.arrow.up")
        }

        Button("Not Now", role: .cancel) { }
    }

    @ViewBuilder
    private var deleteCommentAlertButtons: some View {
        Button("Delete", role: .destructive) {
            if let comment = commentBeingDeleted {
                deleteComment(comment)
            }
        }
        Button("Cancel", role: .cancel) {
            commentBeingDeleted = nil
        }
    }

    @ViewBuilder
    private var deleteUpdateAlertButtons: some View {
        Button("Delete", role: .destructive) {
            if let testimony = storyBeingDeleted {
                deleteStoryUpdate(testimony)
            }
        }
        Button("Cancel", role: .cancel) {
            storyBeingDeleted = nil
        }
    }

    // MARK: - Header

    private func headerCard(for prayer: PrayerRequest) -> some View {
        let mine = isOwner(prayer)
        let following = isFollowingAuthor(prayer)
        let blocked = isBlockedAuthor(prayer)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                prayerAuthorAvatar(for: prayer)

                VStack(alignment: .leading, spacing: 4) {
                    Text(prayer.authorName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PrayerTheme.textPrimary)

                    HStack(spacing: 6) {
                        Text(prayer.timestamp, style: .date)
                        Text("•")
                        Text(prayer.timestamp, style: .time)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(PrayerTheme.textSecondary)
                }

                Spacer()

                if !mine {
                    Menu {
                        Button {
                            prayerReportTarget = prayer
                            showingPrayerReportDialog = true
                        } label: {
                            Label("Report Prayer", systemImage: "exclamationmark.bubble")
                        }

                        Button {
                            prayerReportTarget = prayer
                            showingUserReportDialog = true
                        } label: {
                            Label("Report User", systemImage: "person.crop.circle.badge.exclam")
                        }

                        if !blocked {
                            Button(role: .destructive) {
                                store.blockUser(name: prayer.authorName)
                                reportSentMessage = "\(prayer.authorName) has been blocked."
                                showingReportSentAlert = true
                            } label: {
                                Label("Block User", systemImage: "hand.raised.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(PrayerTheme.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }

                if !mine && !blocked {
                    if following {
                        Text("Following")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .cornerRadius(999)
                    } else {
                        Button {
                            store.addPrayerPartner(
                                name: prayer.authorName,
                                note: "From Prayer Wall"
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Follow")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .prayerCard()
    }

    // MARK: - Content Card

    private func contentCard(for prayer: PrayerRequest) -> some View {
        let hasPrayed = store.profile.prayedPrayerIds.contains(prayer.id)

        return VStack(alignment: .leading, spacing: 12) {
            Text(prayer.text)
                .font(.system(size: 15))
                .foregroundColor(PrayerTheme.textPrimary)
                .multilineTextAlignment(.leading)

            if !prayer.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(prayer.categories, id: \.self) { category in
                            HStack(spacing: 4) {
                                Text(category.emoji)
                                Text(category.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.16))
                            .foregroundColor(.white)
                            .cornerRadius(999)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Label("\(prayer.prayersCount)", systemImage: "hands.sparkles.fill")
                Label("\(prayer.comments.count)", systemImage: "bubble.right.fill")
                Spacer()

                Button {
                    let wasAlreadyPrayed = store.profile.prayedPrayerIds.contains(prayer.id)
                    store.markPraying(for: prayer.id)

                    if !wasAlreadyPrayed {
                        sharePrayerText = """
                        Pray with me in The Prayer Room:

                        \(prayer.text)
                        """
                        showingPostPrayerSharePrompt = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: hasPrayed ? "checkmark.circle.fill" : "hands.sparkles.fill")
                        Text(hasPrayed ? "Praying" : "I’m praying")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minWidth: 44, minHeight: 44, alignment: .center)
                    .background(
                        hasPrayed
                        ? Color.white.opacity(0.08)
                        : Color.white.opacity(0.15)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(999)
                }
                .buttonStyle(.plain)
                .disabled(hasPrayed)
            }
            .font(.system(size: 11))
            .foregroundColor(PrayerTheme.textSecondary)
        }
        .prayerCard()
    }

    // MARK: - Updates Section

    private func updatesSection(for prayer: PrayerRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Updates")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PrayerTheme.textPrimary)

                Spacer()

                if isOwner(prayer) {
                    Button {
                        showingStoryComposer = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Share Update")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.14))
                        .foregroundColor(.white)
                        .cornerRadius(999)
                    }
                    .buttonStyle(.plain)
                }
            }

            if storyTestimonies.isEmpty {
                Text("No updates have been shared yet. When God moves in this story, share it here.")
                    .font(.system(size: 13))
                    .foregroundColor(PrayerTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(storyTestimonies) { testimony in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(testimony.authorName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(PrayerTheme.textPrimary)

                                Spacer()

                                Text(testimony.timestamp, style: .date)
                                    .font(.system(size: 11))
                                    .foregroundColor(PrayerTheme.textSecondary)

                                if isMyStoryUpdate(testimony) {
                                    Menu {
                                        Button {
                                            storyBeingEdited = testimony
                                            editedStoryTitle = testimony.title
                                            editedStoryText = testimony.text
                                            showingEditStorySheet = true
                                        } label: {
                                            Label("Edit Update", systemImage: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            storyBeingDeleted = testimony
                                            showingDeleteStoryAlert = true
                                        } label: {
                                            Label("Delete Update", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(PrayerTheme.textSecondary)
                                            .padding(.leading, 4)
                                    }
                                }
                            }

                            if !testimony.title.isEmpty {
                                Text(testimony.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            Text(testimony.text)
                                .font(.system(size: 13))
                                .foregroundColor(PrayerTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .prayerCard()
    }

    // MARK: - Comments Section

    private func commentsSection(for prayer: PrayerRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Comments")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PrayerTheme.textPrimary)

                Spacer()

                Text("\(prayer.comments.count)")
                    .font(.system(size: 12))
                    .foregroundColor(PrayerTheme.textSecondary)
            }

            if prayer.comments.isEmpty {
                Text("No comments yet. Be the first to encourage them in prayer.")
                    .font(.system(size: 13))
                    .foregroundColor(PrayerTheme.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(prayer.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.authorName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(PrayerTheme.textPrimary)

                                Spacer()

                                Text(comment.timestamp, style: .time)
                                    .font(.system(size: 11))
                                    .foregroundColor(PrayerTheme.textSecondary)

                                if isMyComment(comment) {
                                    Menu {
                                        Button {
                                            commentBeingEdited = comment
                                            editedCommentText = comment.text
                                            showingEditCommentSheet = true
                                        } label: {
                                            Label("Edit Comment", systemImage: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            commentBeingDeleted = comment
                                            showingDeleteCommentAlert = true
                                        } label: {
                                            Label("Delete Comment", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(PrayerTheme.textSecondary)
                                            .padding(.leading, 4)
                                    }
                                } else {
                                    Menu {
                                        Button {
                                            commentBeingReported = comment
                                            showingCommentReportDialog = true
                                        } label: {
                                            Label("Report Comment", systemImage: "exclamationmark.bubble")
                                        }

                                        Button {
                                            commentAuthorNameBeingReported = comment.authorName
                                            showingCommentAuthorReportDialog = true
                                        } label: {
                                            Label("Report User", systemImage: "person.crop.circle.badge.exclam")
                                        }

                                        Button(role: .destructive) {
                                            store.blockUser(name: comment.authorName)
                                            reportSentMessage = "\(comment.authorName) has been blocked."
                                            showingReportSentAlert = true
                                        } label: {
                                            Label("Block User", systemImage: "hand.raised.fill")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(PrayerTheme.textSecondary)
                                            .padding(.leading, 4)
                                    }
                                }
                            }

                            Text(comment.text)
                                .font(.system(size: 13))
                                .foregroundColor(PrayerTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .prayerCard()
    }

    // MARK: - Comment Composer

    private func commentComposer(for prayer: PrayerRequest) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Write a comment to encourage them…", text: $commentText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button {
                submitComment(prayerId: prayer.id)
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.white.opacity(0.15)
                        : PrayerTheme.accent
                    )
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .contentShape(Rectangle())
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func submitComment(prayerId: UUID) {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nameToUse = store.effectiveAuthorName

        print("💬 Submitting comment")
        print("   prayerId:", prayerId)
        print("   author:", nameToUse)
        print("   text:", trimmed)

        store.addComment(
            to: prayerId,
            authorName: nameToUse,
            text: trimmed
        )

        commentText = ""
    }

    private func saveEditedComment() {
        guard let comment = commentBeingEdited else { return }

        let trimmed = editedCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.editComment(comment, newText: trimmed)

        showingEditCommentSheet = false
        commentBeingEdited = nil
        editedCommentText = ""
    }

    private func deleteComment(_ comment: Comment) {
        store.deleteComment(comment)
        commentBeingDeleted = nil
    }

    private func saveEditedStoryUpdate() {
        guard let testimony = storyBeingEdited else { return }

        let trimmedTitle = editedStoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = editedStoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        store.editTestimony(testimony, newTitle: trimmedTitle, newText: trimmedText)

        showingEditStorySheet = false
        storyBeingEdited = nil
        editedStoryTitle = ""
        editedStoryText = ""
    }

    private func deleteStoryUpdate(_ testimony: Testimony) {
        store.deleteTestimony(testimony)
        storyBeingDeleted = nil
    }

    // MARK: - Reporting

    private func reportPrayer(_ prayer: PrayerRequest, reason: String) {
        store.reportContent(
            contentType: "prayer",
            contentId: prayer.id.uuidString,
            reason: reason
        )
        prayerReportTarget = nil
        reportSentMessage = "Thanks for reporting this prayer. We’ll review it."
        showingReportSentAlert = true
    }

    private func reportComment(_ comment: Comment, reason: String) {
        store.reportContent(
            contentType: "comment",
            contentId: comment.id,
            reason: reason
        )
        commentBeingReported = nil
        reportSentMessage = "Thanks for reporting this comment. We’ll review it."
        showingReportSentAlert = true
    }

    private func reportUser(named name: String, reason: String) {
        store.reportContent(
            contentType: "user",
            contentId: name,
            reason: reason
        )
        prayerReportTarget = nil
        commentAuthorNameBeingReported = nil
        reportSentMessage = "Thanks for reporting this user. We’ll review it."
        showingReportSentAlert = true
    }
}

//
// MARK: - Edit Prayer View (with Delete button)
//

struct PrayerEditView: View {
    @EnvironmentObject var store: PrayerStore
    @Environment(\.dismiss) private var dismiss

    let prayerId: UUID
    @State private var text: String
    @State private var selectedCategories: Set<PrayerCategory>

    init(prayer: PrayerRequest) {
        self.prayerId = prayer.id
        _text = State(initialValue: prayer.text)
        _selectedCategories = State(initialValue: Set(prayer.categories))
    }

    private var canSave: Bool {
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
                            Text("Edit Prayer")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)

                            ZStack(alignment: .topLeading) {
                                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Update what you’d like others to be praying with you about.")
                                        .foregroundColor(Color.secondary.opacity(0.7))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 6)
                                }

                                TextEditor(text: $text)
                                    .frame(minHeight: 140)
                                    .scrollContentBackground(.hidden)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Categories")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(PrayerTheme.textPrimary)

                                Text("Adjust the tags so others can discover this prayer in the right areas.")
                                    .font(.system(size: 12))
                                    .foregroundColor(PrayerTheme.textSecondary)

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(PrayerCategory.allCases, id: \.self) { category in
                                        categoryChip(category)
                                    }
                                }
                            }
                        }
                        .prayerCard()
                        .padding(.horizontal)
                        .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Delete Prayer")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red.opacity(0.9))

                            Button(role: .destructive) {
                                deletePrayer()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Delete Prayer")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.18))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .prayerCard()
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(.white)
                    .disabled(!canSave)
                }
            }
        }
    }

    private func categoryChip(_ category: PrayerCategory) -> some View {
        let isSelected = selectedCategories.contains(category)

        return Button {
            if isSelected {
                selectedCategories.remove(category)
            } else {
                selectedCategories.insert(category)
            }
        } label: {
            HStack(spacing: 6) {
                Text(category.emoji)
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(minHeight: 36)
            .padding(.horizontal, 10)
            .background(
                isSelected
                ? Color.white
                : Color.white.opacity(0.10)
            )
            .foregroundColor(isSelected ? Color.black : PrayerTheme.textPrimary)
            .cornerRadius(999)
        }
        .buttonStyle(.plain)
    }

    private func saveChanges() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let categoriesToUse = selectedCategories.isEmpty
            ? [.other]
            : Array(selectedCategories)

        if let index = store.prayers.firstIndex(where: { $0.id == prayerId }) {
            var updated = store.prayers[index]
            updated.text = trimmed
            updated.categories = categoriesToUse
            store.prayers[index] = updated

            Task {
                do {
                    _ = try await store.cloud.savePrayer(updated)
                } catch {
                    print("❌ Failed to save edited prayer to CloudKit:", error)
                }
            }
        }

        dismiss()
    }

    private func deletePrayer() {
        if let index = store.prayers.firstIndex(where: { $0.id == prayerId }) {
            let prayer = store.prayers[index]
            store.deletePrayer(prayer)
        }
        dismiss()
    }
}
