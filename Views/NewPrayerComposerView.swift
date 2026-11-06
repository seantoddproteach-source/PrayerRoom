//
//  NewPrayerComposerView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/16/25.
//

import SwiftUI

struct NewPrayerComposerView: View {
    @EnvironmentObject var store: PrayerStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var text: String = ""
    @State private var selectedCategories: Set<PrayerCategory> = []
    @State private var hasUsedPrayerHelper: Bool = false   // 👈 keeps helper one-time
    
    private let categoryColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 110), spacing: 8)
    ]
    
    /// Name that will be used when posting:
    /// 1) profile.displayName if it's not "New User" / empty
    /// 2) Apple full name from UserDefaults (if available)
    /// 3) "Anonymous" as a last resort
    private var postingName: String {
        let profileName = store.profile.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !profileName.isEmpty && profileName != "New User" {
            return profileName
        }
        
        let appleName = UserDefaults.standard
            .string(forKey: "appleFullName")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if !appleName.isEmpty {
            return appleName
        }
        
        return "Anonymous"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PrayerTheme.gradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Main card: posting name + text + AI helper
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Post a Prayer")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)
                            
                            // Read-only posting name
                            HStack(spacing: 8) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                Text("Posting as \(postingName)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(PrayerTheme.textSecondary)
                            }
                            
                            ZStack(alignment: .topLeading) {
                                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("What can we be praying with you about?")
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
                            
                            // AI-style helper under the TextEditor
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Need help finding the words?")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(PrayerTheme.textPrimary)
                                
                                Button {
                                    if !hasUsedPrayerHelper {
                                        generateSuggestedPrayer()
                                        hasUsedPrayerHelper = true   // 👈 lock after first use
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 14, weight: .medium))
                                        Text(hasUsedPrayerHelper ? "Prayer suggestion added" : "Help me write this prayer")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        hasUsedPrayerHelper
                                        ? Color.white.opacity(0.10)
                                        : Color.white.opacity(0.18)
                                    )
                                    .foregroundColor(.white.opacity(hasUsedPrayerHelper ? 0.6 : 1.0))
                                    .cornerRadius(999)
                                }
                                .buttonStyle(.plain)
                                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                                .disabled(hasUsedPrayerHelper)   // 👈 prevents additional taps
                                
                                Text("We’ll suggest a simple prayer you can edit before posting.")
                                    .font(.system(size: 11))
                                    .foregroundColor(PrayerTheme.textSecondary)
                            }
                            .padding(.top, 4)
                        }
                        .prayerCard()
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        // Categories / tags
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Categories")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(PrayerTheme.textPrimary)
                            
                            Text("Add a few tags so others can discover and stand with you in specific areas.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(PrayerTheme.textSecondary)
                            
                            LazyVGrid(columns: categoryColumns, alignment: .leading, spacing: 8) {
                                ForEach(PrayerCategory.allCases, id: \.self) { category in
                                    categoryChip(category)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
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
                    Button("Post") {
                        submitPrayer()
                    }
                    .foregroundColor(.white)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Category chip
    
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
    
    // MARK: - Submit
    
    private func submitPrayer() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let categoriesToUse = selectedCategories.isEmpty ? [.other] : Array(selectedCategories)
        
        store.addPrayer(
            text: trimmed,
            authorName: postingName,         // 👈 always use resolved name
            categories: categoriesToUse,
            ownerId: store.profile.id
        )
        dismiss()
    }
    
    // MARK: - AI-style helper
    
    private func generateSuggestedPrayer() {
        let trimmedCurrent = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let context: String
        if trimmedCurrent.isEmpty {
            context = "what I’m facing right now"
        } else {
            context = trimmedCurrent
        }
        
        let suggested = """
        Heavenly Father, You see and understand \(context). I’m asking for Your peace, wisdom, and strength in this moment. Help me to trust You with every detail and to remember that I’m not alone. Surround me with Your presence and guide my steps.

        In Jesus’ name, amen.
        """
        
        if trimmedCurrent.isEmpty {
            text = suggested
        } else {
            text = trimmedCurrent + "\n\n" + suggested
        }
    }
}
