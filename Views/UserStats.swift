//
//  UserStats.swift
//  Proclaim & Pray
//
//  Created by Sean todd on 11/30/25.
//

import Foundation

struct UserStats: Identifiable, Hashable {
    /// CloudKit recordName for this user (UserProfile)
    let id: String

    var followers: Int
    var prayersGiven: Int
    var prayersReceived: Int
    
}
