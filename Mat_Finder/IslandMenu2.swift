//
//  IslandMenu2.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/16/25.
//

import Foundation
import SwiftUI
import CoreData
import MapKit
import os
import OSLog // For os_log


// MARK: - View Definition
struct IslandMenu2: View {

    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel

    @State private var islandDetails: IslandDetails = IslandDetails()

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @ObservedObject private var locationManager = UserLocationMapViewModel.shared
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
        case profileLogin = "Login / Create Account" // <-- add this new case
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
            case .profileLogin: return "person.crop.circle.fill.badge.plus" // <-- add here
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


    // With this computed property:
    private var menuItemsFlat: [IslandMenuOption] {
        var items: [IslandMenuOption] = [
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
            .faqDisclaimer
        ]
        
        // Dynamically add profile option depending on auth
        items.append(.profile)  // Only one enum case
        
        return items
    }


    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Text("Mat_Finder")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(menuItemsFlat) { option in
                        if option == .profile && !isLoggedIn {
                            EmptyView()
                        } else if option == .empty {
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
                            renderMenuItem(option)
                        }

                        if option.needsDivider && option != .empty && !(option == .profile && !isLoggedIn) {
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

            BannerView()
                .frame(height: 50) // adjust the height as needed
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(
            ZStack {
                GIFView(name: "flashing2")
                    .frame(width: 500, height: 450)
                    .offset(x: 100, y: -230)
                    .ignoresSafeArea()

                Color.white.opacity(0.1)
            }
        )
        .navigationBarHidden(true)
        .setupListeners(
            showToastMessage: $showToastMessage,
            isToastShown: $isToastShown,
            isLoggedIn: isLoggedIn
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Login Required"),
                message: Text(alertMessage),
                primaryButton: .default(Text("Login In/Create An Account")) {
                    print("➡️ Alert Create An Account/Login tapped, appending to navigationPath")
                    navigationPath.append(AppScreen.login)
                },
                secondaryButton: .cancel()
            )
        }


    }

    @ViewBuilder
    private func renderMenuItem(_ option: IslandMenuOption) -> some View {
        if option == .profile {
            if isLoggedIn {
                // Logged in → go to ProfileView
                NavigationLink {
                    ProfileView(
                        profileViewModel: profileViewModel,
                        authViewModel: authViewModel,
                        selectedTabIndex: .constant(.login),
                        navigationPath: $navigationPath,
                        setupGlobalErrorHandler: { }
                    )
                } label: {
                    menuItemLabel(for: option)
                }
            } else {
                // Not logged in → trigger alert
                Button {
                    alertMessage = "You must be logged in to access your profile. Tap below to log in or create an account."
                    showAlert = true
                } label: {
                    menuItemLabel(for: .profileLogin) // Show "Login / Create Account" text
                }
            }
        } else if restrictedItems.contains(option) && !isLoggedIn {
            Button {
                // Customize alert message for specific restricted items
                switch option {
                case .submitReview:
                    alertMessage = "You must be logged in to submit a review. Tap below to log in or create an account."
                case .dayOfWeek, .addNewGym, .updateExistingGyms, .addOrEditScheduleOpenMat:
                    alertMessage = "You must be logged in to access this feature. Tap below to log in or create an account."
                default:
                    alertMessage = "You must be logged in to access this feature. Tap below to log in or create an account."
                }
                showAlert = true
            } label: {
                menuItemLabel(for: option, locked: true)
            }
        } else {
            NavigationLink(value: navigationDestination(for: option)) {
                menuItemLabel(for: option)
            }
        }
    }


    // MARK: - Menu Item Label
    private func menuItemLabel(for option: IslandMenuOption, locked: Bool = false) -> some View {
        HStack {
            if !option.iconName.isEmpty {
                Image(systemName: option.iconName)
                    .font(.system(size: 20))  // Use a consistent size
                    .frame(width: 25)
                    .foregroundColor(locked ? .secondary : .accentColor) // Use accentColor instead of white
            }

            Text(option.rawValue)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(locked ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.leading, menuLeadingPadding)
    }

    // MARK: - Computed Properties
    private var isLoggedIn: Bool {
        authViewModel.authenticationState.isAuthenticated
    }

    private var restrictedItems: [IslandMenuOption] {
        [.dayOfWeek, .addNewGym, .updateExistingGyms, .addOrEditScheduleOpenMat, .submitReview]
    }

    // MARK: - Navigation Destination
    private func navigationDestination(for option: IslandMenuOption) -> AppScreen {
        switch option {
        case .profile: return .profile
        case .allLocations: return .allLocations
        case .currentLocation: return .currentLocation
        case .postalCode: return .postalCode
        case .dayOfWeek: return .dayOfWeek
        case .addNewGym: return .addNewGym
        case .updateExistingGyms: return .updateExistingGyms
        case .addOrEditScheduleOpenMat: return .addOrEditScheduleOpenMat
        case .searchReviews: return .searchReviews
        case .submitReview: return .selectGymForReview
        case .faqDisclaimer: return .faqDisclaimer
        case .empty: return .profile
        case .profileLogin: return .login

        }
    }
}
