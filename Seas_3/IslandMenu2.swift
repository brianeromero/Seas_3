//
//  IslandMenu2.swift
//  Seas_3
//
//  Created by Brian Romero on 6/16/25.
//

import Foundation
import SwiftUI
import CoreData
import MapKit
import os
import OSLog // For os_log




// (Keep all your dummy types and definitions as provided previously)

// MARK: - View Definition
struct IslandMenu2: View {

    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel

    @State private var islandDetails: IslandDetails = IslandDetails()

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @StateObject private var locationManager = UserLocationMapViewModel()
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var searchResults: [PirateIsland] = []
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    let profileViewModel: ProfileViewModel
    @Binding var navigationPath: NavigationPath

    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false

    // MARK: - Centralized ViewModel/Repository Instantiations
    private let appDayOfWeekRepository: AppDayOfWeekRepository
    private let enterZipCodeViewModelForAppDayOfWeek: EnterZipCodeViewModel
    private let enterZipCodeViewModelForReviews: EnterZipCodeViewModel
    private let pirateIslandViewModel: PirateIslandViewModel

    let menuLeadingPadding: CGFloat = 20

    // MARK: - Initialization
    init(profileViewModel: ProfileViewModel, navigationPath: Binding<NavigationPath>) {
        self.profileViewModel = profileViewModel
        self._navigationPath = navigationPath

        let sharedPersistenceController = PersistenceController.shared
        let appDayOfWeekRepository = AppDayOfWeekRepository(persistenceController: sharedPersistenceController)

        let enterZipCodeViewModelForAppDayOfWeek = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )
        let enterZipCodeViewModelForReviews = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )
        let pirateIslandViewModel = PirateIslandViewModel(persistenceController: sharedPersistenceController)

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: appDayOfWeekRepository,
            enterZipCodeViewModel: enterZipCodeViewModelForAppDayOfWeek
        ))

        self.appDayOfWeekRepository = appDayOfWeekRepository
        self.enterZipCodeViewModelForAppDayOfWeek = enterZipCodeViewModelForAppDayOfWeek
        self.enterZipCodeViewModelForReviews = enterZipCodeViewModelForReviews
        self.pirateIslandViewModel = pirateIslandViewModel
    }

    // MARK: - Enum for Menu Options
    enum IslandMenuOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }

        case profile = "Profile"
        case empty = "" // Used as a placeholder for the first header
        case allLocations = "All Locations"
        case currentLocation = "Current Location"
        case postalCode = "Enter Location"
        case dayOfWeek = "Day of the Week"
        case addNewGym = "Add New Gym"
        case updateExistingGyms = "Update Existing Gyms"
        case addOrEditScheduleOpenMat = "Add or Edit Schedule/Open Mat"
        case searchReviews = "Search Reviews"
        case submitReview = "Submit a Review"
        case faqDisclaimer = "FAQ & Disclaimer"

        var iconName: String {
            switch self {
            case .profile: return "person.crop.circle"
            case .empty: return ""
            case .allLocations: return "map"
            case .currentLocation: return "location.fill"
            case .postalCode: return "location.magnifyingglass"
            case .dayOfWeek: return "calendar"
            case .addNewGym: return "plus.circle"
            case .updateExistingGyms: return "rectangle.and.pencil.and.ellipsis"
            case .addOrEditScheduleOpenMat: return "calendar.badge.plus"
            case .searchReviews: return "text.magnifyingglass"
            case .submitReview: return "bubble.and.pencil"
            case .faqDisclaimer: return "questionmark.circle"
            }
        }

        var needsDivider: Bool {
            switch self {
            case .empty, .dayOfWeek, .addOrEditScheduleOpenMat, .submitReview:
                return true
            default:
                return false
            }
        }

        var dividerHeaderText: String? {
            switch self {
            case .empty: return "Search By"
            case .dayOfWeek: return "Manage Entries"
            case .addOrEditScheduleOpenMat: return "Reviews"
            case .submitReview: return "FAQ"
            default: return nil
            }
        }
    }

    let menuItemsFlat: [IslandMenuOption] = [
        .empty,
        .allLocations,
        .currentLocation,
        .postalCode,
        .dayOfWeek,
        .addNewGym,
        .updateExistingGyms,
        .addOrEditScheduleOpenMat,
        .searchReviews,
        .submitReview,
        .faqDisclaimer,
        .profile
    ]

    // MARK: - Body
    var body: some View {
        // The main content of your menu
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Text("Mat_Finder")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(menuItemsFlat) { option in
                        if option == .empty {
                            if let header = option.dividerHeaderText {
                                Text(header)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, menuLeadingPadding)
                                    .padding(.top, 8)
                            }
                        } else {
                            menuItemView(for: option)
                        }

                        if option.needsDivider && option != .empty {
                            Divider()
                                .padding(.leading, menuLeadingPadding)

                            if let header = option.dividerHeaderText {
                                Text(header)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, menuLeadingPadding)
                                    .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .padding(.top, 10)

            Spacer()
        }
        // CHANGE: Apply the background using the .background() modifier on the main VStack
        .background(
            ZStack { // Use a ZStack within .background if the background itself has multiple layers or specific positioning
                GIFView(name: "flashing2")
                    .frame(width: 500, height: 450)
                    .offset(x: 100, y: -150)
                    .ignoresSafeArea() // Makes the GIF fill the whole screen behind the content
                
                // Add your semi-transparent color background here as well
                Color.white.opacity(0.1) // This creates the subtle overlay you had before
            }
        )
        // Keep other modifiers on the main VStack
        .navigationBarHidden(true)
        .setupListeners(
            showToastMessage: $showToastMessage,
            isToastShown: $isToastShown,
            isLoggedIn: authViewModel.authenticationState.isAuthenticated
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Location Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Extracted View Builders
    @ViewBuilder
    private func menuItemView(for option: IslandMenuOption) -> some View {
        switch option {
        case .profile:
            NavigationLink(value: AppScreen.profile) {
                menuItemLabel(for: option)
            }
        case .allLocations:
            NavigationLink(value: AppScreen.allLocations) {
                menuItemLabel(for: option)
            }
        case .currentLocation:
            NavigationLink(value: AppScreen.currentLocation) {
                menuItemLabel(for: option)
            }
        case .postalCode:
            NavigationLink(value: AppScreen.postalCode) {
                menuItemLabel(for: option)
            }
        case .dayOfWeek:
            NavigationLink(value: AppScreen.dayOfWeek) {
                menuItemLabel(for: option)
            }
        case .addNewGym:
            NavigationLink(value: AppScreen.addNewGym) {
                menuItemLabel(for: option)
            }
        case .updateExistingGyms:
            NavigationLink(value: AppScreen.updateExistingGyms) {
                menuItemLabel(for: option)
            }
        case .addOrEditScheduleOpenMat:
            NavigationLink(value: AppScreen.addOrEditScheduleOpenMat) {
                menuItemLabel(for: option)
            }
        case .searchReviews:
            NavigationLink(value: AppScreen.searchReviews) {
                menuItemLabel(for: option)
            }
        case .submitReview:
            NavigationLink(value: AppScreen.selectGymForReview) {
                menuItemLabel(for: option)
            }
        case .faqDisclaimer:
            NavigationLink(value: AppScreen.faqDisclaimer) {
                menuItemLabel(for: option)
            }
        case .empty:
            EmptyView()
        }
    }

    private func menuItemLabel(for option: IslandMenuOption) -> some View {
        HStack {
            Image(systemName: option.iconName)
                .font(option == .profile ? .title2 : .body)
                .frame(width: option == .profile ? nil : 25)
                .foregroundColor(option == .profile ? .blue : .secondary)
            Text(option.rawValue)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 10)
        .padding(.leading, menuLeadingPadding)
    }
}
