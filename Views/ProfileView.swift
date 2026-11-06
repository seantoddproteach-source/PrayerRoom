//
//  ProfileView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/13/25.
//
import SwiftUI
import UIKit

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var store: PrayerStore
    @State private var showingEditProfile = false
    
    // If name/username still look default, we consider the profile "incomplete"
    private var needsProfileCompletion: Bool {
        let name = resolvedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = store.profile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name == "New User" || username.isEmpty || username == "@username"
    }
    
    /// Pulls from profile.displayName, then Apple full name, then "New User"
    private var resolvedDisplayName: String {
        let profileName = store.profile.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !profileName.isEmpty && profileName != "New User" {
            return profileName
        }
        
        if let appleName = UserDefaults.standard
            .string(forKey: "appleFullName")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !appleName.isEmpty {
            return appleName
        }
        
        return "New User"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()
                
                VStack(spacing: 8) {
                    // 🔼 Top bar
                    HStack {
                        Text("Profile")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button {
                            showingEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 🔽 Scrollable content lives *under* the header
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header card (avatar, name, username, stats)
                            profileHeaderCard
                                .padding(.horizontal)
                            
                            // 🔹 Encouragement badges
                            badgesSection
                                .padding(.horizontal)
                            
                            if needsProfileCompletion {
                                completeProfileCard
                                    .padding(.horizontal)
                            }
                            
                            activitySection
                                .padding(.horizontal)
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                }
            }
            // No navigationTitle, header is inside content
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(store)
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerTopRow
            locationAgeRow
            statsRow
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var headerTopRow: some View {
        HStack(alignment: .center, spacing: 16) {
            profileAvatar
                .frame(width: 70, height: 70)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedDisplayName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(store.profile.username.isEmpty ? "@username" : store.profile.username)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PrayerTheme.textSecondary)
                
                // Bio directly under username
                if !store.profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(store.profile.bio)
                        .font(.system(size: 13))
                        .foregroundColor(PrayerTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                
                // 🔹 Primary prayer focus chip
                if let focus = store.profile.primaryFocus {
                    HStack(spacing: 6) {
                        Text(focus.emoji)
                        Text("Primary focus: \(focus.rawValue)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white)
                    .cornerRadius(999)
                    .padding(.top, 4)
                }
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var locationAgeRow: some View {
        if !store.profile.location.isEmpty || !store.profile.age.isEmpty {
            HStack(spacing: 12) {
                if !store.profile.location.isEmpty {
                    Label(store.profile.location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 11))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
                if !store.profile.age.isEmpty {
                    Label(store.profile.age, systemImage: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
            }
        }
    }
    
    private var profileAvatar: some View {
        Group {
            if let data = store.profile.profileImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
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
                    Text(initials(from: resolvedDisplayName))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func initials(from name: String) -> String {
        let parts = name
            .split(separator: " ")
            .compactMap { $0.first }
        let firstTwo = parts.prefix(2)
        return firstTwo.map { String($0) }.joined()
    }
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            statItem(
                title: "Prayers Given",
                value: store.profile.prayersGiven
            )
            statItem(
                title: "Prayers Posted",
                value: store.prayers.filter {
                    if let ownerId = $0.ownerId {
                        return ownerId == store.profile.id
                    } else {
                        return $0.authorName == resolvedDisplayName
                    }
                }.count
            )
            statItem(
                title: "Partners",
                value: store.profile.partners.count
            )
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
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Badges Section
    
    @ViewBuilder
    private var badgesSection: some View {
        let badges = store.encouragementBadges
        
        if badges.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Encouragement Badges")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(badges.filter { $0.isUnlocked }.count)/\(badges.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .cornerRadius(999)
                }
                
                Text("Badges unlock as you pray for others, share testimonies, and encourage the Prayer Room.")
                    .font(.system(size: 11))
                    .foregroundColor(PrayerTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(badges) { badge in
                            badgeChip(badge)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func badgeChip(_ badge: EncouragementBadge) -> some View {
        let isUnlocked = badge.isUnlocked
        
        return HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [PrayerTheme.accent, PrayerTheme.highlight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.10))
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: badge.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isUnlocked ? .white : PrayerTheme.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(badge.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(PrayerTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(isUnlocked ? 0.14 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(isUnlocked ? 0.18 : 0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Complete Profile Callout
    
    private var completeProfileCard: some View {
        Button {
            showingEditProfile = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Complete your profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PrayerTheme.textPrimary)
                    Text("Add your name and @username so others can recognize and tag you in prayer.")
                        .font(.system(size: 12))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PrayerTheme.textSecondary)
            }
            .padding(14)
            .frame(minHeight: 60)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Your Activity Section
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Activity")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 10) {
                // Your Prayers
                NavigationLink {
                    MyPrayersView()
                        .environmentObject(store)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Prayers")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)
                            Text("View and manage the prayers you’ve posted.")
                                .font(.system(size: 12))
                                .foregroundColor(PrayerTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(PrayerTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Your Testimonies
                NavigationLink {
                    MyTestimoniesView()
                        .environmentObject(store)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Testimonies")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)
                            Text("Review and update the testimonies you’ve shared.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(PrayerTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(PrayerTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Settings
                NavigationLink {
                    SettingsView()
                        .environmentObject(store)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Settings")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)
                            Text("Notifications, theme, guidelines, and support.")
                                .font(.system(size: 12))
                                .foregroundColor(PrayerTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(PrayerTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // 🔹 Blocked People
                NavigationLink {
                    BlockedUsersView()
                        .environmentObject(store)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Blocked People")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)
                            Text("Review and manage who you’ve blocked.")
                                .font(.system(size: 12))
                                .foregroundColor(PrayerTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(PrayerTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject var store: PrayerStore
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("hasCompletedProfileSetup") private var hasCompletedProfileSetup = false
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var age: String = ""
    @State private var location: String = ""
    @State private var bio: String = ""
    @State private var showingPhotoPicker = false
    @State private var selectedImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()
                
                Form {
                    Section {
                        HStack(spacing: 16) {
                            Button {
                                showingPhotoPicker = true
                            } label: {
                                if let image = selectedImage ?? currentProfileImage() {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
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
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Display name", text: $displayName)
                                TextField("Username", text: $username)
                                    .textInputAutocapitalization(.never)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    
                    Section(header: Text("Details")) {
                        TextField("Age", text: $age)
                        TextField("Location", text: $location)
                        TextField("Bio", text: $bio, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hasCompletedProfileSetup = true   // counts as “seen” if they bail
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                loadFromStore()
            }
            .sheet(isPresented: $showingPhotoPicker) {
                ImagePicker(image: $selectedImage)
                    .ignoresSafeArea()
            }
        }
    }
    
    private func loadFromStore() {
        // Prefer saved profile name if it's not default; otherwise fall back to Apple full name
        let trimmedProfileName = store.profile.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedProfileName.isEmpty && trimmedProfileName != "New User" {
            displayName = trimmedProfileName
        } else if let appleName = UserDefaults.standard
                    .string(forKey: "appleFullName")?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !appleName.isEmpty {
            displayName = appleName
        } else {
            displayName = ""
        }
        
        username = store.profile.username
        age = store.profile.age
        location = store.profile.location
        bio = store.profile.bio
        
        if let data = store.profile.profileImageData,
           let image = UIImage(data: data) {
            selectedImage = image
        }
    }
    
    private func saveProfile() {
        // Trim all inputs
        let trimmedName      = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername  = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAge       = age.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation  = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio       = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Start from existing profile
        var updated = store.profile
        
        // Display name
        if !trimmedName.isEmpty {
            updated.displayName = trimmedName
        }
        
        // Username – ensure a single leading "@"
        if !trimmedUsername.isEmpty {
            let cleaned = trimmedUsername
                .replacingOccurrences(of: "^@+", with: "", options: .regularExpression)
            updated.username = "@\(cleaned)"
        }
        
        // Age, location, bio
        if !trimmedAge.isEmpty {
            updated.age = trimmedAge
        }
        if !trimmedLocation.isEmpty {
            updated.location = trimmedLocation
        }
        if !trimmedBio.isEmpty {
            updated.bio = trimmedBio
        }
        
        // Profile image
        if let selectedImage = selectedImage,
           let data = selectedImage.jpegData(compressionQuality: 0.9) {
            updated.profileImageData = data
        }
        
        // Write back to store so @Published fires
        store.profile = updated
        
        // ✅ Save to CloudKit as well
        Task {
            await store.saveProfileToCloud()
        }
        
        hasCompletedProfileSetup = true
        dismiss()
    }
    
    private func currentProfileImage() -> UIImage? {
        if let data = store.profile.profileImageData {
            return UIImage(data: data)
        }
        return nil
    }
}

// MARK: - My Prayers View

struct MyPrayersView: View {
    @EnvironmentObject var store: PrayerStore
    
    private var myPrayers: [PrayerRequest] {
        store.prayers.filter { prayer in
            if let ownerId = prayer.ownerId {
                return ownerId == store.profile.id
            } else {
                // fallback to display name used in UI
                let name = (store.profile.displayName
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            store.profile.displayName == "New User")
                ? (UserDefaults.standard.string(forKey: "appleFullName")?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                : store.profile.displayName
                return prayer.authorName == name
            }
        }
    }
    
    var body: some View {
        List {
            if myPrayers.isEmpty {
                Section {
                    Text("You haven’t posted any prayers yet.")
                        .font(.system(size: 14))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
            } else {
                Section {
                    ForEach(myPrayers) { prayer in
                        PrayerRowView(prayer: prayer)
                            .environmentObject(store)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PrayerTheme.gradient.ignoresSafeArea())
        .navigationTitle("Your Prayers")
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let current = myPrayers
        for index in offsets {
            let prayer = current[index]
            // ✅ Use central helper so CloudKit stays in sync
            store.deletePrayer(prayer)
        }
    }
}

// MARK: - My Testimonies View

struct MyTestimoniesView: View {
    @EnvironmentObject var store: PrayerStore
    
    private var myTestimonies: [Testimony] {
        store.testimonies.filter { t in
            if let ownerId = t.ownerId {
                return ownerId == store.profile.id
            } else {
                // same fallback logic as prayers
                let name = (store.profile.displayName
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            store.profile.displayName == "New User")
                ? (UserDefaults.standard.string(forKey: "appleFullName")?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                : store.profile.displayName
                return t.authorName == name
            }
        }
    }
    
    var body: some View {
        List {
            if myTestimonies.isEmpty {
                Section {
                    Text("You haven’t shared any testimonies yet.")
                        .font(.system(size: 14))
                        .foregroundColor(PrayerTheme.textSecondary)
                }
            } else {
                Section {
                    ForEach(myTestimonies) { testimony in
                        TestimonyRowView(
                            testimony: testimony,
                            isOwner: true,
                            onEdit: { /* hook edit here later if you want */ },
                            onReportTestimony: { },
                                onReportUser: { },
                                onBlockUser: { }


                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PrayerTheme.gradient.ignoresSafeArea())
        .navigationTitle("Your Testimonies")
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let current = myTestimonies
        for index in offsets {
            let t = current[index]
            // ✅ Use central helper so CloudKit stays in sync
            store.deleteTestimony(t)
        }
    }
}

// MARK: - Blocked Users View

struct BlockedUsersView: View {
    @EnvironmentObject var store: PrayerStore
    
    /// Sorted blocked names derived from the profile set
    private var sortedBlockedNames: [String] {
        Array(store.profile.blockedNames).sorted()
    }
    
    var body: some View {
        ZStack {
            PrayerTheme.gradient
                .ignoresSafeArea()
            
            if sortedBlockedNames.isEmpty {
                VStack(spacing: 10) {
                    Text("No blocked people")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PrayerTheme.textPrimary)
                    Text("If you block someone from the Prayer Circle, you’ll see them listed here and can unblock them anytime.")
                        .font(.system(size: 13))
                        .foregroundColor(PrayerTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    Section {
                        ForEach(sortedBlockedNames, id: \.self) { (name: String) in
                            HStack {
                                Text(name)
                                    .foregroundColor(PrayerTheme.textPrimary)
                                Spacer()
                                Button("Unblock") {
                                    // ✅ Use helper so CloudKit is updated
                                    store.unblockUser(name: name)
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.18))
                                .cornerRadius(999)
                            }
                        }
                    } footer: {
                        Text("Unblocking someone may allow their prayers or testimonies to appear again in your feed and suggestions.")
                            .font(.system(size: 11))
                            .foregroundColor(PrayerTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Blocked People")
        .navigationBarTitleDisplayMode(.inline)
    }
}
