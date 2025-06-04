//
//  AppRouter.swift
//  Seas_3
//
//  Created by Brian Romero on 5/30/25.
//

import Foundation
import SwiftUI

class AppRouter: ObservableObject {
    static let shared = AppRouter()

    enum Screen {
        case login
        case main
    }

    @Published var currentScreen: Screen = .login
}
