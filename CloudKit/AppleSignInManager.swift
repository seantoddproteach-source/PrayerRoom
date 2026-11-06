//
//  AppleSignInManager.swift
//  PrayerRoom
//
//  Created by Sean todd on 11/17/25.
//

import Foundation
import AuthenticationServices
import SwiftUI

final class AppleSignInManager: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    
    @AppStorage("appleUserID") private var storedAppleUserID: String = ""
    
    // MARK: - Restore
    
    func restoreSignInState() {
        if !storedAppleUserID.isEmpty {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }
    
    // MARK: - Handle Result
    
    func handleAuthorization(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            
            let userID = credential.user
            storedAppleUserID = userID
            isAuthenticated = true
            
            // 🔹 Store full name on *first* sign-in if available
            if let fullName = credential.fullName {
                let formatter = PersonNameComponentsFormatter()
                let name = formatter.string(from: fullName)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !name.isEmpty {
                    UserDefaults.standard.set(name, forKey: "appleFullName")
                    #if DEBUG
                    print("🍎 Stored Apple full name:", name)
                    #endif
                }
            }
            
        case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
            isAuthenticated = false
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        storedAppleUserID = ""
        isAuthenticated = false
        // Optional: clear apple name as well
        // UserDefaults.standard.removeObject(forKey: "appleFullName")
    }
}
