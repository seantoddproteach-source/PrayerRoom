//
//  ModerationService.swift
//  Proclaim & Pray
//
//  Created by Sean todd on 3/13/26.
//

import Foundation

enum ModerationResult {
    case clean
    case flagged(reason: String)
    case blocked(reason: String)
}

struct ModerationService {

    static let bannedWords: [String] = [
        "porn",
        "sex",
        "hate",
        "kill",
        "racist",
        "Fuck",
        "Bitch",
        "Ass",
        "Hell",
        "Lucifer"
    ]

    static let spamPhrases: [String] = [
        "buy now",
        "click here",
        "cash app",
        "dm me",
        "crypto"
        
    ]

    static func moderate(_ text: String) -> ModerationResult {

        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return .blocked(reason: "Content cannot be empty.")
        }

        for word in bannedWords {
            if normalized.contains(word) {
                return .blocked(reason: "This content includes language that is not allowed.")
            }
        }

        for phrase in spamPhrases {
            if normalized.contains(phrase) {
                return .flagged(reason: "This content looks like spam.")
            }
        }

        if normalized.count > 1500 {
            return .flagged(reason: "Content is unusually long and needs review.")
        }

        return .clean
    }
}
