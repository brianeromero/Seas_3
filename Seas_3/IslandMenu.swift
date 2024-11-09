// IslandMenu.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import MapKit

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
    @StateObject var profileViewModel: ProfileViewModel
    let persistenceController: PersistenceController
    let menuLeadingPadding: CGFloat = 50 + 0.5 * 10


    // MARK: - Initialization
    init(persistenceController: PersistenceController, isLoggedIn: Binding<Bool>, profileViewModel: ProfileViewModel) {
        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: AppDayOfWeekRepository(persistenceController: persistenceController),
            enterZipCodeViewModel: EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository(persistenceController: persistenceController),
                context: persistenceController.container.viewContext
            )
        ))
        self.persistenceController = persistenceController
        self._isLoggedIn = isLoggedIn
        self._profileViewModel = StateObject(wrappedValue: profileViewModel)
    }

    enum IslandMenuOption: String, CaseIterable {
        case allLocations = "All Locations"
        case currentLocation = "Current Location"
        case zipCode = "Zip Code"
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
            IslandMenuOption.zipCode.rawValue,
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
    }

    // MARK: - View Builders
    private var menuHeaderView: some View {
        Text("Main Menu")
            .font(.title)
            .bold()
            .padding(.top, 1)
    }

    private var menuItemView: some View {
        ForEach(menuItems, id: \.id) { menuItem in
            VStack(alignment: .leading, spacing: 0) {
                Text(menuItem.title)
                    .font(.headline)
                
                ForEach(menuItem.subMenuItems, id: \.self) { subMenuItem in
                    NavigationLink(destination: destinationView(for: IslandMenuOption(rawValue: subMenuItem)!)) {
                        Text(subMenuItem)
                            .foregroundColor(.blue)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 1)
                    }
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
        switch option {
        case .addNewGym:
            AddNewIsland(viewModel: PirateIslandViewModel(persistenceController: persistenceController), profileViewModel: profileViewModel)
        case .updateExistingGyms:
            EditExistingIslandList()
        case .allLocations:
            AllEnteredLocations(context: viewContext)
        case .currentLocation:
            ConsolidatedIslandMapView(
                viewModel: appDayOfWeekViewModel,
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository(persistenceController: persistenceController),
                    context: persistenceController.container.viewContext
                )
            )
        case .zipCode:
            EnterZipCodeView(
                appDayOfWeekViewModel: appDayOfWeekViewModel,
                allEnteredLocationsViewModel: AllEnteredLocationsViewModel(
                    dataManager: PirateIslandDataManager(viewContext: viewContext)
                ),
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository(persistenceController: persistenceController),
                    context: persistenceController.container.viewContext
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
                selectedAppDayOfWeek: .constant(nil),
                region: $region,
                searchResults: $searchResults
            )
        case .searchReviews:
            ViewReviewSearch(
                selectedIsland: $selectedIsland,
                enterZipCodeViewModel: appDayOfWeekViewModel.enterZipCodeViewModel
            )
        case .submitReview:
            GymMatReviewSelect(
                selectedIsland: $selectedIsland,
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository(persistenceController: persistenceController),
                    context: viewContext
                )
            )
            .navigationTitle("Select Gym for Review")
            .navigationBarTitleDisplayMode(.inline)
        case .faqDisclaimer:
            FAQnDisclaimerMenuView()
        }
    }
}

// MARK: - Preview
struct IslandMenu_Previews: PreviewProvider {
    static var previews: some View {
        // Accessing the preview context from PersistenceController
        let previewContext = PersistenceController.preview.container.viewContext
        
        // Initializing ProfileViewModel with viewContext
        let profileViewModel = ProfileViewModel(viewContext: previewContext)
        
        // Creating the IslandMenu view with dependencies
        return IslandMenu(
            persistenceController: PersistenceController.preview,
            isLoggedIn: .constant(true),
            profileViewModel: profileViewModel
        )
        .environment(\.managedObjectContext, previewContext)
    }
}
