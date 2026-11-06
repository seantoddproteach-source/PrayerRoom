//
//  PersonProfileView.swift
//  Proclaim & Pray
//
//  Created by Sean todd on 12/17/25.
//

import SwiftUI
import UIKit

struct PersonProfileView: View {
    @EnvironmentObject var store: PrayerStore

    let displayName: String
    let username: String?

    @State private var remoteProfile: UserProfile? = nil
    @State private var didLoadProfile = false

    init(displayName: String, username: String? = nil) {
        self.displayName = displayName
        self.username = username
    }

    // MARK: - Derived

    private var isBlocked: Bool { store.isBlocked(name: displayName) }
    private var isFollowing: Bool { store.isFollowing(name: displayName) }

    private var cleanedUsername: String? {
        guard let u = username?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty else { return nil }
        return u.hasPrefix("@") ? u : "@\(u)"
    }

    private var initials: String {
        let parts = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .compactMap { $0.first }
        let two = parts.prefix(2).map { String($0) }.joined()
        return two.isEmpty ? String(displayName.prefix(1)).uppercased() : two.uppercased()
    }

    private var isCurrentUser: Bool {
        let trimmedDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let myDisplay = store.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedDisplay.caseInsensitiveCompare(myDisplay) == .orderedSame {
            return true
        }

        if let remoteProfile {
            return remoteProfile.id == store.profile.id
        }

        return false
    }

    private var userPrayers: [PrayerRequest] {
        store.prayers
            .filter { prayer in
                if let ownerId = prayer.ownerId {
                    if isCurrentUser {
                        return ownerId == store.profile.id
                    } else if let remoteProfile {
                        return ownerId == remoteProfile.id
                    }
                }

                return prayer.authorName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(displayName.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var profileImageDataToShow: Data? {
        if isCurrentUser {
            return store.profile.profileImageData
        } else {
            return remoteProfile?.profileImageData
        }
    }

    // MARK: - UI

    var body: some View {
        ZStack {
            PrayerTheme.gradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {

                    headerCard
                        .padding(.horizontal)
                        .padding(.top, 8)

                    prayersCard
                        .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didLoadProfile else { return }
            didLoadProfile = true

            if !isCurrentUser {
                remoteProfile = await store.loadRemoteProfileForPerson(
                    displayName: displayName,
                    username: cleanedUsername
                )
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                avatarView

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    if let u = cleanedUsername {
                        Text(u)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(PrayerTheme.textSecondary)
                    } else {
                        Text("Prayer Partner")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(PrayerTheme.textSecondary)
                    }
                }

                Spacer()

                if isCurrentUser {
                    EmptyView()
                } else if isBlocked {
                    Button { store.unblockUser(name: displayName) } label: {
                        Text("Unblock")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.16))
                            .foregroundColor(.white)
                            .cornerRadius(999)
                    }
                    .buttonStyle(.plain)
                } else if isFollowing {
                    Button { store.unfollow(name: displayName) } label: {
                        Text("Following")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.16))
                            .foregroundColor(.white)
                            .cornerRadius(999)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { store.follow(name: displayName, note: cleanedUsername ?? "") } label: {
                        Text("Follow")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
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

            HStack(spacing: 12) {
                statItem(title: "Prayers", value: userPrayers.count)
                statItem(title: "Partner", value: isFollowing ? 1 : 0)
                statItem(title: "Blocked", value: isBlocked ? 1 : 0)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        if let data = profileImageDataToShow,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
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
                    .frame(width: 64, height: 64)

                Text(initials)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    private func statItem(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(PrayerTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Prayers Feed

    private var prayersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prayers")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            if isBlocked {
                Text("You’ve blocked this person. Unblock them to see their prayers.")
                    .font(.system(size: 13))
                    .foregroundColor(PrayerTheme.textSecondary)
            } else if userPrayers.isEmpty {
                Text("No prayers posted yet.")
                    .font(.system(size: 13))
                    .foregroundColor(PrayerTheme.textSecondary)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(userPrayers) { prayer in
                        NavigationLink {
                            PrayerDetailView(prayerId: prayer.id)
                        } label: {
                            PrayerRowView(prayer: prayer)
                                .environmentObject(store)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
