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
    @Environment(\.dismiss) var dismiss // ✅ Correct way to use @Environment(\.dismiss)
    @EnvironmentObject var authViewModel: AuthViewModel // Changed from @ObservedObject to @EnvironmentObject
    @EnvironmentObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel

    @State private var navigationPath = NavigationPath()
    
    @State private var islandDetails = IslandDetails()

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @StateObject private var locationManager = UserLocationMapViewModel()
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var searchResults: [PirateIsland] = []
    // @Binding var isLoggedIn: Bool // REMOVED - Derived from authViewModel
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    let profileViewModel: ProfileViewModel
    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false
    
    // ADD THESE BINDINGS:
    @Binding var showGlobalToast: Bool
    @Binding var globalToastMessage: String
    @Binding var globalToastType: ToastView.ToastType

    

    // MARK: - Centralized ViewModel/Repository Instantiations
    private let appDayOfWeekRepository: AppDayOfWeekRepository
    private let enterZipCodeViewModelForAppDayOfWeek: EnterZipCodeViewModel
    private let enterZipCodeViewModelForReviews: EnterZipCodeViewModel
    private let pirateIslandViewModel: PirateIslandViewModel

    let menuLeadingPadding: CGFloat = 50 + 0.5 * 10

    // MARK: - Initialization
    init(
        profileViewModel: ProfileViewModel,
        // Add the new binding parameters here
        showGlobalToast: Binding<Bool>,
        globalToastMessage: Binding<String>,
        globalToastType: Binding<ToastView.ToastType>
    ) {
        os_log("User logged in", log: IslandMenulogger)
        os_log("Initializing IslandMenu", log: IslandMenulogger)

        self.profileViewModel = profileViewModel

        // Initialize the new bindings
        _showGlobalToast = showGlobalToast
        _globalToastMessage = globalToastMessage
        _globalToastType = globalToastType


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

    enum IslandMenuOption: String, CaseIterable {
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
        ZStack {
            GIFView(name: "flashing2")
                .frame(width: 500, height: 450)
                .offset(x: 100, y: -150)

            menuView
        }
        // Moved .navigationBarTitle here
        .navigationBarTitle("Welcome to Mat_Finder", displayMode: .inline)
        .setupListeners(
            showToastMessage: $showToastMessage,
            isToastShown: $isToastShown,
            isLoggedIn: authViewModel.authenticationState.isAuthenticated // Derived from EnvironmentObject
        )
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
        .onChange(of: authViewModel.authenticationState.isAuthenticated) { oldValue, newValue in
            if !newValue {
                os_log("IslandMenu: Authentication state changed to false, dismissing any modals.", log: IslandMenulogger)
            }
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
            authViewModel: authViewModel, // authViewModel is now @EnvironmentObject, so this is correct
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

    // Removed .navigationBarTitle from here
    private var menuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuHeaderView
            menuItemView
            profileLinkView
        }
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
        switch option {
        case .addNewGym:
            return AnyView(
                AddNewIsland(
                    // ✅ No longer pass these explicitly, AddNewIsland should get them from the environment
                    // islandViewModel: pirateIslandViewModel,
                    // profileViewModel: profileViewModel,
                    // authViewModel: authViewModel,
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
            )


        case .updateExistingGyms:
            return AnyView(
                EditExistingIslandList(
                    navigationPath: $navigationPath, // Already there
                    showGlobalToast: $showGlobalToast,       // <-- ADD THIS
                    globalToastMessage: $globalToastMessage, // <-- ADD THIS
                    globalToastType: $globalToastType        // <-- ADD THIS
                )
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
                AllEnteredLocations(
                    viewModel: allEnteredLocationsViewModel, // Use the instance from EnvironmentObject
                    navigationPath: $navigationPath // Pass the binding for navigationPath
                )
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
                    enterZipCodeViewModel: enterZipCodeViewModelForAppDayOfWeek,
                    navigationPath: $navigationPath // <--- Add this line!
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
                    allEnteredLocationsViewModel: allEnteredLocationsViewModel,
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
                    appDayOfWeekViewModel: appDayOfWeekViewModel,
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
                DayOfWeekSearchView()
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
                    navigationPath: $navigationPath // <--- PASS THE BINDING HERE!
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
    // No longer needs authViewModel if its only purpose was for logging in .onAppear,
    // as it's now an @EnvironmentObject in IslandMenu and can be passed explicitly if LogView has other uses.
    // If LogView genuinely needs authViewModel for its own purposes (not just logging), keep it.
    // For now, assuming it's only for the message.
    // If you need authViewModel for internal logic of LogView, declare it as @EnvironmentObject here too.
    // @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        EmptyView()
            .onAppear {
                os_log("%@", log: IslandMenulogger, message)
            }
    }
}
