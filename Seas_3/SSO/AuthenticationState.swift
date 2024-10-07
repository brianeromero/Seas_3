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
    @Published public var isAuthenticated: Bool = false
}
