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
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var authViewModel: AuthViewModel
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


    let menuLeadingPadding: CGFloat = 50 + 0.5 * 10
    
    // MARK: - Initialization
    // Log authentication event
    init(isLoggedIn: Binding<Bool>, authViewModel: AuthViewModel, profileViewModel: ProfileViewModel) {
        os_log("User logged in", log: IslandMenulogger)
        os_log("Initializing IslandMenu", log: IslandMenulogger)

        self.authViewModel = authViewModel  // Initialize authViewModel
        self._isLoggedIn = isLoggedIn
        self.profileViewModel = profileViewModel // Initialize profileViewModel

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
            enterZipCodeViewModel: EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
                persistenceController: PersistenceController.shared
            )
        ))
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
                isLoggedIn: isLoggedIn // Use the Binding<Bool> you already have
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
                        NavigationLink(destination: destinationView(for: option)) {
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
            authViewModel: authViewModel,
            selectedTabIndex: .constant(LoginViewSelection.login),
            setupGlobalErrorHandler: {}
        )) {
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
    @ViewBuilder
    private func destinationView(for option: IslandMenuOption) -> some View {

        LogView(message: "Destination view for \(option.rawValue)")

        switch option {
        case .addNewGym:
            AddNewIsland(
                islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                profileViewModel: profileViewModel,
                authViewModel: authViewModel,
                islandDetails: $islandDetails  
            )


        case .updateExistingGyms:
            EditExistingIslandList()
            
        case .allLocations:
            AllEnteredLocations()
            
        case .currentLocation:
            ConsolidatedIslandMapView(
                viewModel: appDayOfWeekViewModel,
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
                    persistenceController: PersistenceController.shared
                )
            )
            
        case .postalCode:
            EnterZipCodeView(
                appDayOfWeekViewModel: appDayOfWeekViewModel,
                allEnteredLocationsViewModel: AllEnteredLocationsViewModel(
                    dataManager: PirateIslandDataManager(viewContext: PersistenceController.shared.container.viewContext)
                ),
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
                    persistenceController: PersistenceController.shared
                )
            )
            .alert(isPresented: $showAlert) {
                handleInvalidZipCode()
            }
            
        case .addOrEditScheduleOpenMat:
            DaysOfWeekFormView(
                viewModel: appDayOfWeekViewModel,
                selectedIsland: $selectedIsland,
                selectedMatTime: .constant(nil),
                showReview: .constant(false)
            )
            
        case .dayOfWeek:
            DayOfWeekSearchView(
                selectedIsland: $selectedIsland,
                selectedAppDayOfWeek: .constant(nil),  // Add this
                region: $region,                      // Add this
                searchResults: $searchResults        // Add this
            )

            
        case .searchReviews:
            ViewReviewSearch(
                selectedIsland: $selectedIsland,
                titleString: "Read Gym Reviews",
                enterZipCodeViewModel: appDayOfWeekViewModel.enterZipCodeViewModel,
                authViewModel: authViewModel // Add this parameter
            )


            
        case .submitReview:
            GymMatReviewSelect(
                selectedIsland: $selectedIsland,
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
                    persistenceController: PersistenceController.shared
                ),
                authViewModel: authViewModel
            )

            
        case .faqDisclaimer:
            FAQnDisclaimerMenuView()
        }
    }
}

struct LogView: View {
    let message: String
    
    var body: some View {
        EmptyView()
        .onAppear {
            os_log("%@", log: IslandMenulogger, message)
        }
    }
}
