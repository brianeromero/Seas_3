//
//  AuthenticationState.swift
//  Seas_3
//
//  Created by Brian Romero on 10/5/24.
//

import Foundation
import SwiftUI
import Combine

public class AuthenticationState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published public private(set) var facebookUser: FacebookUser?
    @Published var googleUser: GoogleUser?

    @Published var user: UserInfo?

    
    public struct FacebookUser {
        let id: String?
        let name: String?
        let email: String?
    }
    
    
    public struct GoogleUser {
        let id: String?
        let name: String?
        let email: String?
    }
    
    public func updateFacebookUser(_ userId: String?, _ userName: String?, _ userEmail: String?) {
        guard let userId = userId, let userName = userName, let userEmail = userEmail else {
            print("Invalid Facebook user data")
            return
        }
        
        facebookUser = FacebookUser(id: userId, name: userName, email: userEmail)
        isAuthenticated = true
    }
    
    
    public func updateGoogleUser(_ userId: String?, _ userName: String?, _ userEmail: String?) {
        guard let userId = userId, let userName = userName, let userEmail = userEmail else {
            print("Invalid Google user data")
            return
        }
        
        googleUser = GoogleUser(id: userId, name: userName, email: userEmail)
        isAuthenticated = true
    }
    
    public func resetFacebookUser() {
        facebookUser = nil
        isAuthenticated = false
    }
    
    public func updateGoogleUser() {
        isAuthenticated = true
    }
    
    func login(_ user: UserInfo) {
        isAuthenticated = true
        self.user = user
    }
    
    func logout() {
        isAuthenticated = false
        self.user = nil
    }
    
}

