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
    @Binding var navigationPath: NavigationPath // ✅ Keep this binding

    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false


    // MARK: - Centralized ViewModel/Repository Instantiations
    private let appDayOfWeekRepository: AppDayOfWeekRepository
    private let enterZipCodeViewModelForAppDayOfWeek: EnterZipCodeViewModel
    private let enterZipCodeViewModelForReviews: EnterZipCodeViewModel
    private let pirateIslandViewModel: PirateIslandViewModel

    // Adjusted padding to match the visual layout in the image
    let menuLeadingPadding: CGFloat = 20


    // MARK: - Initialization
    init(profileViewModel: ProfileViewModel, navigationPath: Binding<NavigationPath>) {
        os_log("User logged in", log: IslandMenulogger)
        os_log("Initializing IslandMenu", log: IslandMenulogger)

        self.profileViewModel = profileViewModel
        self._navigationPath = navigationPath // Proper way to bind a @Binding var

        let sharedPersistenceController = PersistenceController.shared
        self.appDayOfWeekRepository = AppDayOfWeekRepository(persistenceController: sharedPersistenceController)

        self.enterZipCodeViewModelForAppDayOfWeek = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )
        self.enterZipCodeViewModelForReviews = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )

        self.pirateIslandViewModel = PirateIslandViewModel(persistenceController: sharedPersistenceController)

        let localAppDayOfWeekRepository = self.appDayOfWeekRepository
        let localEnterZipCodeViewModel = self.enterZipCodeViewModelForAppDayOfWeek

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: localAppDayOfWeekRepository,
            enterZipCodeViewModel: localEnterZipCodeViewModel
        ))
    }

    // New Enum to represent all menu options
    enum IslandMenuOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }

        case profile = "Profile"
        case empty = ""
        case allLocations = "All Locations"
        case currentLocation = "Current Location"
        case postalCode = "Postal Code"
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
            case .empty: return true
            case .dayOfWeek: return true
            case .addOrEditScheduleOpenMat: return true
            case .submitReview: return true
            default: return false
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
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Text("Mat_Finder") // Placeholder for your logo/brand name
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Render all menu items from menuItemsFlat
                        ForEach(menuItemsFlat) { option in
                            NavigationLink {
                                destinationView(for: option)
                            } label: {
                                HStack {
                                    Image(systemName: option.iconName)
                                        .font(option == .profile ? .title2 : .body) // Larger icon for Profile
                                        .frame(width: option == .profile ? nil : 25) // Fixed width for other icons
                                        .foregroundColor(option == .profile ? .blue : .secondary) // .secondary will adapt
                                    Text(option.rawValue)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary) // Automatically black in Light, white/light gray in Dark
                                    Spacer()
                                }
                                .padding(.vertical, 10) // Padding for each menu item
                                .padding(.leading, menuLeadingPadding)
                            }
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded {
                                        os_log("User tapped menu item: %@", log: IslandMenulogger, option.rawValue)
                                    }
                            )

                            if option.needsDivider {
                                Divider()
                                    .padding(.leading, menuLeadingPadding) // Indent divider

                                if let header = option.dividerHeaderText {
                                    Text(header)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                        .padding(.leading, menuLeadingPadding + 5)
                                        .padding(.top, 8)
                                        .padding(.bottom, 4)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)

                Spacer()

                
 /*
                 // Bottom Navigation Bar
                 HStack {
                     Spacer()
                     VStack {
                         Image(systemName: "house.fill")
                             .font(.title2)
                         Text("Home")
                             .font(.caption)
                     }
                     .foregroundColor(.blue) // Highlight selected/active icon
                     Spacer()
                     VStack {
                         Image(systemName: "magnifyingglass")
                             .font(.title2)
                         Text("Search")
                             .font(.caption)
                     }
                     Spacer()
                     VStack {
                         Image(systemName: "heart.fill")
                             .font(.title2)
                         Text("Favorites")
                             .font(.caption)
                     }
                     Spacer()
                     VStack {
                         Image(systemName: "person.fill")
                             .font(.title2)
                         Text("Profile")
                             .font(.caption)
                     }
                     Spacer()
                 }

                 
                 .padding(.vertical, 8)
                 .background(Color.white.shadow(radius: 2)) // Add a subtle shadow
 */
        
            }
            // ✨ NEW: Move GIFView to the background modifier of the VStack
            .background(
                GIFView(name: "flashing2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available background space
                    .offset(x: 120, y: -170) // Maintain original offset for positioning of the GIF itself
                    .opacity(0.3)
                    .scaleEffect(0.65) // Scale down the GIF's visual size
                    .ignoresSafeArea() // Make the GIF background ignore safe areas
                    .background(Color.clear) // Ensure it doesn't have an opaque background itself if GIF has transparency
            )


            .navigationBarHidden(true) // Hide default navigation bar for custom header
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
            .onAppear {
                os_log("IslandMenu2 appeared", log: IslandMenulogger)
            }
            .onChange(of: authViewModel.authenticationState.isAuthenticated) { oldValue, newValue in
                if !newValue {
                    os_log("IslandMenu: Authentication state changed to false, dismissing any modals.", log: IslandMenulogger)
                }
            }
        } // End of NavigationView
    }
    // MARK: - Destination View
    @ViewBuilder // Add @ViewBuilder here
    private func destinationView(for option: IslandMenuOption) -> some View {
        switch option {
        case .profile:
            ProfileView(
                profileViewModel: profileViewModel,
                // Re-added the missing arguments
                authViewModel: authViewModel, // Pass it explicitly if ProfileView's init takes it
                selectedTabIndex: .constant(LoginViewSelection.login), // Provide a constant binding
                setupGlobalErrorHandler: {} // Provide an empty closure
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("ProfileView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }
        
        case .addNewGym:
            AddNewIsland(
                islandViewModel: pirateIslandViewModel,
                profileViewModel: profileViewModel,
                authViewModel: authViewModel,
                navigationPath: $navigationPath,
                islandDetails: $islandDetails
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("AddNewIsland Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .updateExistingGyms:
            EditExistingIslandList()
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("EditExistingIslandList Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .allLocations:
            AllEnteredLocations()
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("AllEnteredLocations Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .currentLocation:
            ConsolidatedIslandMapView(
                viewModel: appDayOfWeekViewModel,
                enterZipCodeViewModel: enterZipCodeViewModelForAppDayOfWeek
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("ConsolidatedIslandMapView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .postalCode:
            EnterZipCodeView(
                appDayOfWeekViewModel: appDayOfWeekViewModel,
                allEnteredLocationsViewModel: allEnteredLocationsViewModel,
                // If EnterZipCodeView's init requires enterZipCodeViewModel, pass it
                enterZipCodeViewModel: enterZipCodeViewModelForAppDayOfWeek
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("EnterZipCodeView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .addOrEditScheduleOpenMat:
            DaysOfWeekFormView(
                viewModel: appDayOfWeekViewModel,
                selectedIsland: $selectedIsland,
                selectedMatTime: .constant(nil),
                showReview: .constant(false)
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("DaysOfWeekFormView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .dayOfWeek:
            DayOfWeekSearchView(
                selectedIsland: $selectedIsland,
                selectedAppDayOfWeek: .constant(nil),
                region: $region,
                searchResults: $searchResults
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("DayOfWeekSearchView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .searchReviews:
            ViewReviewSearch(
                selectedIsland: $selectedIsland,
                titleString: "Read Gym Reviews"
                // enterZipCodeViewModel and authViewModel are @EnvironmentObjects in ViewReviewSearch
                // enterZipCodeViewModel: enterZipCodeViewModelForReviews, // REMOVED
                // authViewModel: authViewModel // REMOVED
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("ViewReviewSearch Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .submitReview:
            GymMatReviewSelect(
                selectedIsland: $selectedIsland,
                // If GymMatReviewSelect's init requires these, pass them
                enterZipCodeViewModel: enterZipCodeViewModelForReviews,
                authViewModel: authViewModel,
                navigationPath: $navigationPath 
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("GymMatReviewSelect Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .faqDisclaimer:
            FAQnDisclaimerMenuView()
            .onAppear { // Log when FAQnDisclaimerMenuView actually appears
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("FAQnDisclaimerMenuView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }
        //case .recentlyViewed, .more:
            // For these new menu items, you'll need to define their actual destination views.
            // For now, they will navigate to a placeholder text view.
            //Text("Destination for \(option.rawValue)")
        case .empty:
            Text("")
        }
    }
}
