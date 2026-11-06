//
//  PrayerFeedView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/13/25.
//

import SwiftUI
import UIKit

// MARK: - Feed Segment (For You / Prayer Partners / Saved)

private enum PrayerWallSegment: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case partners = "Prayer Partners"
    case saved = "Saved"
    
    var id: String { rawValue }
}

struct PrayerFeedView: View {
    @EnvironmentObject var store: PrayerStore
    @State private var selectedSegment: PrayerWallSegment = .forYou
    @State private var selectedCategoryFilter: PrayerCategory? = nil  // nil = All
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var showingComposer: Bool = false
    
    // Names of partners + the current user
    private var partnerNames: Set<String> {
        var names = Set(store.profile.partners.map { $0.name })
        names.insert(store.profile.displayName)
        return names
    }
    
    // Helper: is an author blocked?
    private func isAuthorBlocked(_ authorName: String) -> Bool {
        let trimmedAuthor = authorName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return store.profile.blockedNames.contains { blocked in
            blocked.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmedAuthor) == .orderedSame
        }
    }
    
    // Prayers shown in current tab and category filter and search
    private var displayedPrayers: [PrayerRequest] {
        // 1) Segment filter
        let base: [PrayerRequest]
        switch selectedSegment {
        case .forYou:
            base = store.prayers
        case .partners:
            base = store.prayers.filter { partnerNames.contains($0.authorName) }
        case .saved:
            base = store.prayers.filter { store.isSaved(prayerId: $0.id) }
        }
        
        // 1.5) Strip out blocked authors for *all* segments
        let unblockedBase = base.filter { prayer in
            !isAuthorBlocked(prayer.authorName)
        }
        
        // 2) Category filter
        let categoryFiltered: [PrayerRequest]
        if let category = selectedCategoryFilter {
            categoryFiltered = unblockedBase.filter { $0.categories.contains(category) }
        } else {
            categoryFiltered = unblockedBase
        }
        
        // 3) Search filter
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else {
            return categoryFiltered
        }
        
        return categoryFiltered.filter { prayer in
            prayer.text.localizedCaseInsensitiveContains(trimmedSearch) ||
            prayer.authorName.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()
                
                VStack(spacing: 8) {
                    
                    // Top bar: title + BIG New Prayer button + search icon
                    HStack(spacing: 8) {
                        Text("Prayer Wall")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // BIG pill-style New Prayer button
                        Button {
                            showingComposer = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
                                Text("New Prayer")
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
                        
                        // Search toggle button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearching.toggle()
                            }
                        } label: {
                            Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Inline search field (shows when magnifying glass is tapped)
                    if isSearching {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(PrayerTheme.textSecondary)
                            TextField("Search prayers or names", text: $searchText)
                                .textInputAutocapitalization(.none)
                                .disableAutocorrection(false)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Top segmented tabs
                    segmentTabs
                        .padding(.horizontal)
                    
                    // Category filter bar
                    categoryFilterBar
                        .padding(.horizontal)
                    
                    // MAIN FEED AREA (ScrollView + LazyVStack, like Testimony view)
                    ScrollView {
                        if displayedPrayers.isEmpty {
                            VStack(spacing: 10) {
                                emptyState
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(displayedPrayers) { prayer in
                                    
                                    // Determine if this prayer belongs to the current user
                                    let isOwner: Bool = {
                                        if let ownerId = prayer.ownerId {
                                            return ownerId == store.profile.id
                                        } else {
                                            return prayer.authorName
                                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                                .caseInsensitiveCompare(store.effectiveAuthorName) == .orderedSame
                                        }
                                    }()
                                    
                                    NavigationLink {
                                        PrayerDetailView(prayerId: prayer.id)
                                    } label: {
                                        PrayerRowView(prayer: prayer)
                                            .environmentObject(store)
                                    }
                                    .buttonStyle(.plain)
                                    // Swipe-to-delete → use PrayerStore’s CloudKit-backed delete
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if isOwner {
                                            Button(role: .destructive) {
                                                deletePrayer(prayer)
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
                        await store.refreshPrayers()
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                NewPrayerComposerView()
                    .environmentObject(store)
            }
        }
    }
    
    // MARK: - Segment Tabs
    
    private var segmentTabs: some View {
        HStack(spacing: 4) {
            ForEach(PrayerWallSegment.allCases) { segment in
                Button {
                    selectedSegment = segment
                } label: {
                    Text(segment.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 4)
                        .background(
                            Group {
                                if selectedSegment == segment {
                                    Color.white
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .foregroundColor(
                            selectedSegment == segment
                            ? Color.black
                            : PrayerTheme.textSecondary
                        )
                        .cornerRadius(999)
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.10))
        .cornerRadius(999)
    }
    
    // MARK: - Category Filter Bar
    
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                Button {
                    selectedCategoryFilter = nil
                } label: {
                    Text("All")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(minHeight: 44)
                        .padding(.horizontal, 10)
                        .background(
                            selectedCategoryFilter == nil
                            ? Color.white
                            : Color.white.opacity(0.10)
                        )
                        .foregroundColor(
                            selectedCategoryFilter == nil
                            ? Color.black
                            : PrayerTheme.textPrimary
                        )
                        .cornerRadius(999)
                }
                .buttonStyle(.plain)
                
                ForEach(PrayerCategory.allCases, id: \.self) { category in
                    let isSelected = selectedCategoryFilter == category
                    Button {
                        if isSelected {
                            selectedCategoryFilter = nil
                        } else {
                            selectedCategoryFilter = category
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(category.emoji)
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(minHeight: 44)
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
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No prayers match your search")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PrayerTheme.textPrimary)
                Text("Try a different phrase, name, or remove some filters.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PrayerTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                switch selectedSegment {
                case .forYou:
                    Text("No prayer requests yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(PrayerTheme.textPrimary)
                    Text("Tap the New Prayer button above to share something we can be praying with you about.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                case .partners:
                    Text("No partner prayers yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(PrayerTheme.textPrimary)
                    Text("Invite prayer partners or encourage them to share their requests.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                case .saved:
                    Text("No saved prayers yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(PrayerTheme.textPrimary)
                    Text("Tap the bookmark icon on any prayer to save it here.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Delete helper
    
    private func deletePrayer(_ prayer: PrayerRequest) {
        // Use PrayerStore’s CloudKit-backed delete
        store.deletePrayer(prayer)
    }
}

// MARK: - Row (showing tags + bookmark + avatar logic)

struct PrayerRowView: View {
    @EnvironmentObject var store: PrayerStore
    let prayer: PrayerRequest
    
    @State private var remoteProfile: UserProfile? = nil
    @State private var didLoadProfile = false
    
    // Is this prayer authored by the current user?
    private var isCurrentUsersPrayer: Bool {
        if let ownerId = prayer.ownerId {
            return ownerId == store.profile.id
        } else {
            return prayer.authorName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(store.effectiveAuthorName) == .orderedSame
        }
    }
    
    private var displayNameTrimmed: String {
        prayer.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Avatar: use my profile image, else remote profile image, else fallback initial
    @ViewBuilder
    private var avatarView: some View {
        if isCurrentUsersPrayer,
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
                    Text(prayer.authorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PrayerTheme.textPrimary)
                    Text(prayer.timestamp, style: .time)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
                Spacer()
                
                // ⭐ Bookmark button – 44x44 tap area
                Button {
                    store.toggleSaved(prayerId: prayer.id)
                } label: {
                    Image(systemName: store.isSaved(prayerId: prayer.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(
                            store.isSaved(prayerId: prayer.id)
                            ? PrayerTheme.highlight
                            : PrayerTheme.textSecondary
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            Text(prayer.text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(PrayerTheme.textPrimary)
                .multilineTextAlignment(.leading)
            
            // Tags row
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
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(999)
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                Label("\(prayer.prayersCount)", systemImage: "hands.sparkles.fill")
                    .font(.system(size: 11, weight: .regular))
                Label("\(prayer.comments.count)", systemImage: "bubble.right.fill")
                    .font(.system(size: 11, weight: .regular))
                Spacer()
            }
            .foregroundColor(PrayerTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .prayerCard()
        .task {
            guard !isCurrentUsersPrayer else { return }
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
