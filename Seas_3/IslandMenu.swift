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
    
    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @StateObject private var locationManager = UserLocationMapViewModel()
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var searchResults: [PirateIsland] = []
    @Binding var isLoggedIn: Bool
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    let menuLeadingPadding: CGFloat = 50 + 0.5 * 10
    
    // MARK: - Initialization
    // Log authentication event
    init(isLoggedIn: Binding<Bool>) {
        os_log("User logged in", log: IslandMenulogger)
        os_log("Initializing IslandMenu", log: logger)
        
        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
            enterZipCodeViewModel: EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
                persistenceController: PersistenceController.shared
            )
        ))

        self._isLoggedIn = isLoggedIn
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
            os_log("IslandMenu appeared", log: logger)
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
                    // Log user interaction
                    NavigationLink(destination: destinationView(for: IslandMenuOption(rawValue: subMenuItem)!)) {
                        Text(subMenuItem)
                            .foregroundColor(.blue)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 1)
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                os_log("User tapped %@", log: IslandMenulogger, "\(subMenuItem) button")
                            }
                    )
                }
            }
            .padding(.bottom, CGFloat(Padding.menuItem))
        }
    }
    
    private var profileLinkView: some View {
        NavigationLink(destination: ProfileView(profileViewModel: profileViewModel)) {
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
            // Use the shared persistence controller in the view model
            AddNewIsland(
                viewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                profileViewModel: profileViewModel
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
            .onAppear {
                if appDayOfWeekViewModel.enterZipCodeViewModel.postalCode.isEmpty || !appDayOfWeekViewModel.enterZipCodeViewModel.isValidPostalCode() {
                    os_log("Invalid zip code", log: IslandMenulogger)
                }
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
                selectedAppDayOfWeek: .constant(nil),
                region: $region,
                searchResults: $searchResults
            )
            
        case .searchReviews:
            ViewReviewSearch(
                selectedIsland: $selectedIsland,
                titleString: "Explore Gym Reviews",
                enterZipCodeViewModel: appDayOfWeekViewModel.enterZipCodeViewModel
            )
            
        case .submitReview:
            GymMatReviewSelect(
                selectedIsland: $selectedIsland,
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
                    persistenceController: PersistenceController.shared
                )
            )
            .navigationTitle("Select Gym for Review")
            .navigationBarTitleDisplayMode(.inline)
            
        case .faqDisclaimer:
            FAQnDisclaimerMenuView()
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
}

// MARK: - Preview
struct IslandMenu_Previews: PreviewProvider {
    static var previews: some View {
        let previewContext = PersistenceController.preview.container.viewContext
        
        return NavigationView {
            IslandMenu(isLoggedIn: .constant(true))
                .environment(\.managedObjectContext, previewContext)
                .environmentObject(ProfileViewModel(
                    viewContext: PersistenceController.preview.container.viewContext,
                    authViewModel: AuthViewModel.shared
                ))
        }
    }
}
