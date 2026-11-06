//
//  InstructionsView.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/20/25.
//

import SwiftUI

struct InstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex: Int = 0
    
    private let pages: [InstructionsPage] = [
        InstructionsPage(
            id: 0,
            icon: "hands.sparkles.fill",
            title: "Prayer Wall",
            subtitle: "Share What’s On Your Heart",
            description: "Post prayer requests, pray for others with a tap, and watch how God moves in community.",
            accentColor: .blue
        ),
        InstructionsPage(
            id: 1,
            icon: "quote.bubble.fill",
            title: "Testimonies",
            subtitle: "Tell The Story",
            description: "When prayers are answered, share the testimony so others can be encouraged and build their faith.",
            accentColor: .purple
        ),
        InstructionsPage(
            id: 2,
            icon: "link.circle.fill",
            title: "Threads & Stories",
            subtitle: "Follow The Journey",
            description: "Turn a prayer request into a story thread. Add updates over time so people can follow along.",
            accentColor: .orange
        ),
        InstructionsPage(
            id: 3,
            icon: "star.circle.fill",
            title: "Encouragement Badges",
            subtitle: "Celebrate Faithfulness",
            description: "Badges unlock as you pray for others, share testimonies, and encourage the Prayer Room.",
            accentColor: .yellow
        ),
        InstructionsPage(
            id: 4,
            icon: "flame.fill",
            title: "Proclaim Meter",
            subtitle: "Grow Your Impact",
            description: "Your Proclaim Meter grows as you pray, post stories, and encourage others — a gentle nudge to keep going.",
            accentColor: .pink
        )
    ]
    
    var body: some View {
        ZStack {
            PrayerTheme.gradient
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How Proclaim Works")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Swipe to explore the main features.")
                            .font(.system(size: 14))
                            .foregroundColor(PrayerTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                Spacer(minLength: 8)
                
                // Paged cards
                TabView(selection: $currentIndex) {
                    ForEach(pages) { page in
                        InstructionCardView(page: page)
                            .padding(.horizontal, 24)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // custom dots
                .frame(maxHeight: 380) // 🔹 keeps cards from being huge
                
                // Custom page dots
                HStack(spacing: 8) {
                    ForEach(pages) { page in
                        Circle()
                            .fill(page.id == currentIndex ? Color.white : Color.white.opacity(0.25))
                            .frame(width: page.id == currentIndex ? 10 : 6,
                                   height: page.id == currentIndex ? 10 : 6)
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: currentIndex)
                    }
                }
                .padding(.top, 4)
                
                // Bottom button
                Button {
                    if currentIndex < pages.count - 1 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            currentIndex += 1
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentIndex < pages.count - 1 ? "Next" : "Get Started")
                            .font(.system(size: 16, weight: .semibold))
                        if currentIndex < pages.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(999)
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Page Model

struct InstructionsPage: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let accentColor: Color
}

// MARK: - Card View

struct InstructionCardView: View {
    let page: InstructionsPage
    
    var body: some View {
        VStack(spacing: 18) {
            // Icon in soft glass circle
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(radius: 8, y: 4)
                
                Image(systemName: page.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            
            VStack(spacing: 6) {
                Text(page.subtitle.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PrayerTheme.textSecondary)
                    .tracking(1)
                
                Text(page.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            
            Text(page.description)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(PrayerTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 480, maxHeight: 260) // 🔹 smaller, cleaner card
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.25), value: page.id)
    }
}
