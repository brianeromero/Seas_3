//
//  AppState.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var showWelcomeScreen = true
    @Published var selectedDestination: Destination?
}

enum Destination {
    case home
    case profile
    case settings
}
