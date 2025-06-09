// IslandMenu.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import MapKit
import os

let IslandMenulogger = OSLog(subsystem: "Seas3.Subsystem", category: "IslandMenu")

enum Padding {
    static let menuItem = 20
    static let menuHeader = 15
}
// MARK: - View Definition
struct IslandMenu: View {

    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss // Updated for iOS 15+
    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel // <-- ADD THIS LINE

    @State private var islandDetails = IslandDetails()

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @StateObject private var locationManager = UserLocationMapViewModel()
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var searchResults: [PirateIsland] = []
    @Binding var isLoggedIn: Bool
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    let profileViewModel: ProfileViewModel
    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false

    // MARK: - Centralized ViewModel/Repository Instantiations
    private let appDayOfWeekRepository: AppDayOfWeekRepository
    private let enterZipCodeViewModelForAppDayOfWeek: EnterZipCodeViewModel
    private let enterZipCodeViewModelForReviews: EnterZipCodeViewModel
    private let pirateIslandViewModel: PirateIslandViewModel
    // private let pirateIslandDataManager: PirateIslandDataManager // <-- REMOVE THIS LINE (No longer needed here)

    let menuLeadingPadding: CGFloat = 50 + 0.5 * 10

    // MARK: - Initialization
    init(isLoggedIn: Binding<Bool>, authViewModel: AuthViewModel, profileViewModel: ProfileViewModel) {
        os_log("User logged in", log: IslandMenulogger)
        os_log("Initializing IslandMenu", log: IslandMenulogger)

        // If authViewModel is now an @EnvironmentObject, you should remove this 'self.authViewModel' line.
        // If it's *only* passed to IslandMenu and not an environment object *everywhere*, keep it.
        // Based on your AppRootView, authViewModel is an @EnvironmentObject from AppDelegate.
        // So, this line should be removed if it's truly an @EnvironmentObject.
        self.authViewModel = authViewModel // <-- UNCOMMENT THIS LINE if authViewModel is *not* an @EnvironmentObject, or remove @ObservedObject and use @EnvironmentObject if it is.

        self._isLoggedIn = isLoggedIn
        self.profileViewModel = profileViewModel

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
        // self.pirateIslandDataManager = PirateIslandDataManager(viewContext: sharedPersistenceController.container.viewContext) // <-- REMOVE THIS LINE

        let localAppDayOfWeekRepository = self.appDayOfWeekRepository
        let localEnterZipCodeViewModel = self.enterZipCodeViewModelForAppDayOfWeek

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: localAppDayOfWeekRepository,
            enterZipCodeViewModel: localEnterZipCodeViewModel
        ))

        // No need to initialize _allEnteredLocationsViewModel here for Option 2, it's injected.
    }

    enum IslandMenuOption: String, CaseIterable {
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
    }

    let menuItems: [MenuItem] = [
        .init(title: "Search Gym Entries By", subMenuItems: [
            IslandMenuOption.allLocations.rawValue,
            IslandMenuOption.currentLocation.rawValue,
            IslandMenuOption.postalCode.rawValue,
            IslandMenuOption.dayOfWeek.rawValue
        ], padding: 20),
        .init(title: "Manage Gyms Entries", subMenuItems: [
            IslandMenuOption.addNewGym.rawValue,
            IslandMenuOption.updateExistingGyms.rawValue,
            IslandMenuOption.addOrEditScheduleOpenMat.rawValue
        ], padding: 15),
        .init(title: "Reviews", subMenuItems: [
            IslandMenuOption.searchReviews.rawValue,
            IslandMenuOption.submitReview.rawValue
        ], padding: 20),
        .init(title: "FAQ", subMenuItems: [
            IslandMenuOption.faqDisclaimer.rawValue
        ], padding: 20)
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                GIFView(name: "flashing2")
                    .frame(width: 500, height: 450)
                    .offset(x: 100, y: -150)

                if isLoggedIn {
                    menuView
                } else {
                    loginPromptView
                }
            }
            .setupListeners(
                showToastMessage: $showToastMessage,
                isToastShown: $isToastShown,
                isLoggedIn: isLoggedIn
            )
        }
        .edgesIgnoringSafeArea(.all)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Location Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            os_log("IslandMenu appeared", log: IslandMenulogger)
        }
    }


    // MARK: - View Builders
    private var menuHeaderView: some View {
        Text("Main Menu")
            .font(.title)
            .bold()
            .padding(.top, 1)
    }



    private var menuItemView: some View {
        ForEach(menuItems, id: \.title) { menuItem in
            VStack(alignment: .leading, spacing: 0) {
                Text(menuItem.title)
                    .font(.headline)

                ForEach(menuItem.subMenuItems, id: \.self) { subMenuItem in
                    if let option = IslandMenuOption(rawValue: subMenuItem) {
                        // This NavigationLink closure is lazily evaluated.
                        NavigationLink {
                            destinationView(for: option)
                        } label: {
                            Text(subMenuItem)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 1)
                        }
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded {
                                    // This log fires ONLY when the user taps
                                    os_log("User tapped menu item: %@", log: IslandMenulogger, subMenuItem)
                                }
                        )
                    } else {
                        Text(subMenuItem)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.bottom, CGFloat(Padding.menuItem))
        }
    }

    private var profileLinkView: some View {
        NavigationLink(destination: ProfileView(
            profileViewModel: profileViewModel,
            authViewModel: authViewModel,
            selectedTabIndex: .constant(LoginViewSelection.login),
            setupGlobalErrorHandler: {}
        )
        .onAppear { // Log when ProfileView appears
            let userID = authViewModel.currentUserID ?? "Unknown"
            let timestamp = "\(Date())"
            os_log("ProfileView Appeared. User: %@. Time: %@",
                    log: IslandMenulogger,
                    type: .info,
                    userID,
                    timestamp
            )
        }) {
            Label("Profile", systemImage: "person.crop.circle.fill")
                .font(.headline)
                .padding(.bottom, 1)
        }
        .padding(.top, 40)
    }

    private var menuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuHeaderView
            menuItemView
            profileLinkView
        }
        .navigationBarTitle("Welcome to Mat_Finder", displayMode: .inline)
        .padding(.leading, menuLeadingPadding)
    }


    private var loginPromptView: some View {
        Text("Please log in to access the menu.")
            .font(.headline)
            .padding()
    }

    private func handleInvalidZipCode() -> Alert {
        Alert(
            title: Text("Invalid Zip Code"),
            message: Text("Please enter a valid zip code."),
            dismissButton: .default(Text("OK"))
        )
    }

    // MARK: - Destination View
    private func destinationView(for option: IslandMenuOption) -> some View {

        // IMPORTANT: REMOVE os_log from here! It's executed eagerly for all links.
        // If you need to log when the view *appears*, add .onAppear to the destination view itself.

        switch option {
        case .addNewGym:
            return AnyView(
                AddNewIsland(
                    islandViewModel: pirateIslandViewModel,
                    profileViewModel: profileViewModel,
                    authViewModel: authViewModel,
                    islandDetails: $islandDetails
                )
                .onAppear { // Log when this specific view appears
                    let userID = authViewModel.currentUserID ?? "Unknown"
                    let timestamp = "\(Date())"
                    os_log("AddNewIsland Appeared. User: %@. Time: %@",
                            log: IslandMenulogger,
                            type: .info,
                            userID,
                            timestamp
                    )
                }
            )

        case .updateExistingGyms:
            return AnyView(
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
            )

        case .allLocations:
            return AnyView(
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
            )

        case .currentLocation:
            return AnyView(
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
            )

        case .postalCode:
            return AnyView(
                EnterZipCodeView(
                    appDayOfWeekViewModel: appDayOfWeekViewModel,
                    allEnteredLocationsViewModel: allEnteredLocationsViewModel, // <-- USE THE ENVIRONMENT OBJECT HERE
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
            )

        case .addOrEditScheduleOpenMat:
            return AnyView(
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
            )

        case .dayOfWeek:
            return AnyView(
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
            )

        case .searchReviews:
            return AnyView(
                ViewReviewSearch(
                    selectedIsland: $selectedIsland,
                    titleString: "Read Gym Reviews",
                    enterZipCodeViewModel: enterZipCodeViewModelForReviews,
                    authViewModel: authViewModel
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
            )

        case .submitReview:
            return AnyView(
                GymMatReviewSelect(
                    selectedIsland: $selectedIsland,
                    enterZipCodeViewModel: enterZipCodeViewModelForReviews,
                    authViewModel: authViewModel
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
            )

        case .faqDisclaimer:
            return AnyView(
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
            )
        }
    }
}


struct LogView: View {
    let message: String
    let authViewModel: AuthViewModel // Keep if LogView has other UI purposes that need authViewModel

    var body: some View {
        EmptyView()
            .onAppear {
                os_log("%@", log: IslandMenulogger, message)
            }
    }
}
