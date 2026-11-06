//import SwiftUI

import SwiftUI
import UIKit

// ==========================================================
// MARK: - PeopleView (Drop-in, Unfollow Only, No Edit Sheet)
// - Added profile pictures for partners + directory results
// ==========================================================

struct PeopleView: View {
    @EnvironmentObject var store: PrayerStore

    // 🔍 Search state
    @State private var searchText: String = ""
    @State private var isSearchingDirectory: Bool = false
    @State private var directoryResults: [DirectoryUser] = []
    @State private var searchError: String? = nil

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bookmarkedPrayers: [PrayerRequest] {
        let savedIds = Set(store.profile.savedPrayerIds)
        return store.prayers
            .filter { savedIds.contains($0.id) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Local Filtering

    private var filteredPartners: [PrayerPartner] {
        let all = store.profile.partners
        guard !searchQuery.isEmpty else { return all }
        return all.filter { partner in
            partner.name.localizedCaseInsensitiveContains(searchQuery) ||
            partner.note.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    // MARK: - UI

    var body: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient.ignoresSafeArea()

                VStack(spacing: 8) {
                    HStack {
                        Text("Prayer Circle")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    ScrollView {
                        VStack(spacing: 18) {
                            PeopleHeaderCard()

                            searchBar

                            BookmarkedPrayersSummaryCard(prayers: bookmarkedPrayers)

                            PartnersSectionInstagram(
                                partners: filteredPartners,
                                searchQuery: searchQuery
                            )
                            .environmentObject(store)

                            if !searchQuery.isEmpty {
                                DirectoryResultsSection(
                                    results: directoryResults,
                                    isSearching: isSearchingDirectory,
                                    searchQuery: searchQuery,
                                    errorMessage: searchError
                                )
                                .environmentObject(store)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(PrayerTheme.textSecondary)

            TextField("Search people or @username", text: $searchText)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(.white)
                .submitLabel(.search)
                .onSubmit { triggerDirectorySearch(for: searchText) }
                .onChange(of: searchText) { triggerDirectorySearch(for: $0) }

            if !searchQuery.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Directory Search Logic (GLOBAL)

    private func triggerDirectorySearch(for rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            isSearchingDirectory = false
            directoryResults = []
            searchError = nil
            return
        }

        guard trimmed.count >= 2 else {
            isSearchingDirectory = false
            directoryResults = []
            searchError = nil
            return
        }

        let normalized = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed

        isSearchingDirectory = true
        searchError = nil

        Task {
            do {
                let results = try await store.searchDirectoryUsers(matching: normalized)
                await MainActor.run {
                    self.directoryResults = results
                    self.isSearchingDirectory = false
                }
            } catch {
                await MainActor.run {
                    self.directoryResults = []
                    self.isSearchingDirectory = false
                    self.searchError = "Something went wrong while searching. Please try again."
                }
            }
        }
    }
}

// ==========================================================
// MARK: - Header Card
// ==========================================================

private struct PeopleHeaderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome to your Prayer Circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(PrayerTheme.textPrimary)

            Text("Search for people, follow prayer partners, and keep your bookmarked prayers organized. Build your prayer circle, stay connected with others, and support one another through shared prayer.")
                .font(.system(size: 13))
                .foregroundColor(PrayerTheme.textSecondary)
        }
        .prayerCard()
    }
}

// ==========================================================
// MARK: - Bookmarked Summary
// ==========================================================

private struct BookmarkedPrayersSummaryCard: View {
    let prayers: [PrayerRequest]
    private var count: Int { prayers.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bookmarked Prayers")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PrayerTheme.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundColor(PrayerTheme.textSecondary)
            }

            NavigationLink {
                BookmarkedPrayersView(initialFilter: nil)
            } label: {
                HStack {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("View Bookmarked Prayers")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(Color.white.opacity(0.12))
                .cornerRadius(14)
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            if count == 0 {
                Text("You haven’t bookmarked any prayers yet. Tap the bookmark icon on a prayer to save it here.")
                    .font(.system(size: 12))
                    .foregroundColor(PrayerTheme.textSecondary)
            }
        }
        .prayerCard()
    }
}

// ==========================================================
// MARK: - Partners (Instagram Following list, Unfollow Only)
// ==========================================================

private struct PartnersSectionInstagram: View {
    @EnvironmentObject var store: PrayerStore
    let partners: [PrayerPartner]
    let searchQuery: String

    private var sortedPartners: [PrayerPartner] {
        partners.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prayer Partners")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PrayerTheme.textPrimary)
                Spacer()
                Text("\(store.profile.partners.count)")
                    .font(.system(size: 13))
                    .foregroundColor(PrayerTheme.textSecondary)
            }

            if store.profile.partners.isEmpty {
                Text("You’re not following anyone yet. Search above and follow people you know.")
                    .font(.system(size: 13))
                    .foregroundColor(PrayerTheme.textSecondary)

            } else if sortedPartners.isEmpty && !searchQuery.isEmpty {
                Text("No partners match your search.")
                    .font(.system(size: 13))
                    .foregroundColor(PrayerTheme.textSecondary)

            } else {
                VStack(spacing: 0) {
                    ForEach(sortedPartners) { partner in
                        PartnerCompactRow(partner: partner)
                            .environmentObject(store)

                        if partner.id != sortedPartners.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.10))
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
        }
        .prayerCard()
    }
}

private struct PartnerCompactRow: View {
    @EnvironmentObject var store: PrayerStore
    let partner: PrayerPartner

    @State private var remoteProfile: UserProfile? = nil
    @State private var didLoadProfile = false

    private var partnerUsername: String? {
        let trimmed = partner.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var initials: String {
        let parts = partner.name.split(separator: " ").compactMap { $0.first }
        let firstTwo = parts.prefix(2).map { String($0) }.joined()
        return firstTwo.isEmpty ? String(partner.name.prefix(1)) : firstTwo
    }

    @ViewBuilder
    private var avatarView: some View {
        if let data = remoteProfile?.profileImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
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
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 40, height: 40)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [PrayerTheme.accent, PrayerTheme.highlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 40, height: 40)

                Text(initials.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 2) {
                NavigationLink {
                    PersonProfileView(displayName: partner.name, username: partnerUsername)
                } label: {
                    Text(partner.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(PrayerTheme.textPrimary)
                }
                .buttonStyle(.plain)

                if let u = partnerUsername, !u.isEmpty {
                    Text(u)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("Following")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    store.unfollow(name: partner.name)
                } label: {
                    Label("Unfollow", systemImage: "person.crop.circle.badge.minus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .task {
            guard !didLoadProfile else { return }
            didLoadProfile = true

            let trimmedName = partner.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let username = partnerUsername

            guard !trimmedName.isEmpty || (username?.isEmpty == false) else { return }

            if let fetched = await store.loadRemoteProfileForPerson(displayName: trimmedName, username: username) {
                self.remoteProfile = fetched
            }
        }
    }
}

// ==========================================================
// MARK: - Directory Search Results
// ==========================================================

private struct DirectoryResultsSection: View {
    @EnvironmentObject var store: PrayerStore
    let results: [DirectoryUser]
    let isSearching: Bool
    let searchQuery: String
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("People Search")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PrayerTheme.textPrimary)
                Spacer()
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.9))
            } else if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Searching \"\(searchQuery)\"…")
                        .font(.system(size: 13))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
            } else if !searchQuery.isEmpty && results.isEmpty {
                Text("No people found matching \"\(searchQuery)\" yet.")
                    .font(.system(size: 13))
                    .foregroundColor(PrayerTheme.textSecondary)
            } else if !results.isEmpty {
                VStack(spacing: 8) {
                    ForEach(results) { user in
                        DirectoryUserRow(user: user)
                            .environmentObject(store)
                    }
                }
            }
        }
        .prayerCard()
    }
}

private struct DirectoryUserRow: View {
    @EnvironmentObject var store: PrayerStore
    let user: DirectoryUser

    @State private var remoteProfile: UserProfile? = nil
    @State private var didLoadProfile = false

    private var displayInitial: String {
        if !user.displayName.isEmpty { return String(user.displayName.prefix(1)).uppercased() }
        if let username = user.username, !username.isEmpty {
            return String(username.replacingOccurrences(of: "@", with: "").prefix(1)).uppercased()
        }
        return "?"
    }

    private var formattedUsername: String? {
        guard let username = user.username, !username.isEmpty else { return nil }
        return username.hasPrefix("@") ? username : "@\(username)"
    }

    private var isBlocked: Bool { store.isBlocked(name: user.displayName) }
    private var isFollowing: Bool { store.isFollowing(name: user.displayName) }

    @ViewBuilder
    private var avatarView: some View {
        if let data = remoteProfile?.profileImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
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
                .opacity(isBlocked ? 0.6 : 1.0)
        } else {
            Circle()
                .fill(Color.white.opacity(isBlocked ? 0.08 : 0.16))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(displayInitial)
                        .foregroundColor(.white.opacity(isBlocked ? 0.6 : 1.0))
                        .font(.system(size: 15, weight: .bold))
                )
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            avatarView

            VStack(alignment: .leading, spacing: 2) {
                NavigationLink {
                    PersonProfileView(displayName: user.displayName, username: formattedUsername)
                } label: {
                    Text(user.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isBlocked ? PrayerTheme.textSecondary.opacity(0.8) : PrayerTheme.textPrimary)
                }
                .buttonStyle(.plain)

                if let username = formattedUsername {
                    Text(username)
                        .font(.system(size: 12))
                        .foregroundColor(PrayerTheme.textSecondary)
                }

                if let bio = user.bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(bio)
                        .font(.system(size: 11))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isBlocked {
                Button { store.unblockUser(name: user.displayName) } label: {
                    Text("Unblock")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.16))
                        .foregroundColor(.white)
                        .cornerRadius(999)
                }
                .buttonStyle(.plain)
            } else if isFollowing {
                Button { store.unfollow(name: user.displayName) } label: {
                    Text("Following")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.16))
                        .foregroundColor(.white)
                        .cornerRadius(999)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    let note = formattedUsername ?? ""
                    store.follow(name: user.displayName, note: note)
                } label: {
                    Text("Follow")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
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
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .task {
            guard !didLoadProfile else { return }
            didLoadProfile = true

            let trimmedName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let username = formattedUsername

            guard !trimmedName.isEmpty || (username?.isEmpty == false) else { return }

            if let fetched = await store.loadRemoteProfileForPerson(displayName: trimmedName, username: username) {
                self.remoteProfile = fetched
            }
        }
    }
}
