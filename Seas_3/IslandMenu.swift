// IslandMenu.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import MapKit

struct IslandMenu: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @StateObject private var locationManager = UserLocationMapViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedAppDayOfWeek: AppDayOfWeek? = nil
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var searchResults: [PirateIsland] = []
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @Binding var isLoggedIn: Bool // Add this binding
    
    @StateObject var profileViewModel: ProfileViewModel // Add ProfileViewModel here

    let persistenceController: PersistenceController

    private var appDayOfWeekRepository: AppDayOfWeekRepository {
        return AppDayOfWeekRepository(persistenceController: persistenceController)
    }

    private var pirateIslandDataManager: PirateIslandDataManager {
        return PirateIslandDataManager(viewContext: viewContext)
    }

    // Menu items
    let menuItems: [MenuItem] = [
        .init(title: "Search Gym Entries By", subMenuItems: ["All Locations", "Current Location", "ZipCode", "Day of the Week"]),
        .init(title: "Manage Gyms Entries", subMenuItems: ["Add New Gym", "Update Existing Gyms", "Add or Edit Schedule/Open Mat"]),
        .init(title: "Reviews", subMenuItems: ["Search Reviews", "Submit a Review"]),
        .init(title: "FAQ", subMenuItems: ["FAQ & Disclaimer"])
    ]

    init(persistenceController: PersistenceController, isLoggedIn: Binding<Bool>, profileViewModel: ProfileViewModel) { // Update initializer
        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: AppDayOfWeekRepository(persistenceController: persistenceController),
            enterZipCodeViewModel: EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository(persistenceController: persistenceController),
                context: persistenceController.container.viewContext
            )
        ))
        self.persistenceController = persistenceController
        self._isLoggedIn = isLoggedIn // Initialize the binding
        self._profileViewModel = StateObject(wrappedValue: profileViewModel) // Initialize ProfileViewModel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GIFView(name: "flashing2")
                    .frame(width: 500, height: 450)
                    .offset(x: 100, y: -150)

                // Conditionally present the menu or a login prompt
                if isLoggedIn {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Main Menu")
                            .font(.title)
                            .bold()
                            .padding(.top, 1)

                        ForEach(menuItems) { menuItem in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(menuItem.title)
                                    .font(.headline)
                                    .padding(.bottom, 1)

                                if let subMenuItems = menuItem.subMenuItems {
                                    ForEach(subMenuItems, id: \.self) { subMenuItem in
                                        NavigationLink(destination: destinationView(for: subMenuItem)) {
                                            Text(subMenuItem)
                                                .foregroundColor(.blue)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.leading, 1)
                                                .padding(.top, 5)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }

                        NavigationLink(destination: ProfileView(profileViewModel: profileViewModel)) {
                            Label("Profile", systemImage: "person.crop.circle.fill")
                                .font(.headline)
                                .padding(.bottom, 1)
                        }

                        .padding(.bottom, 20)
                    }
                    .navigationBarTitle("Welcome to Mat_Finder", displayMode: .inline)
                    .padding(.leading, 50)
                } else {
                    // Show a login prompt or a message
                    Text("Please log in to access the menu.")
                        .font(.headline)
                        .padding()
                    // Here you might want to include a button to show the login view
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

    @ViewBuilder
    private func destinationView(for menuItem: String) -> some View {
        switch menuItem {
        case "Add New Gym":
            AddNewIsland(viewModel: PirateIslandViewModel(persistenceController: persistenceController), profileViewModel: profileViewModel) // Pass profileViewModel here
        case "Update Existing Gyms":
            EditExistingIslandList()
        case "All Locations":
            AllEnteredLocations(context: viewContext)
        case "Current Location":
            ConsolidatedIslandMapView(
                viewModel: AppDayOfWeekViewModel(
                    selectedIsland: nil,
                    repository: appDayOfWeekRepository,
                    enterZipCodeViewModel: EnterZipCodeViewModel(
                        repository: appDayOfWeekRepository,
                        context: persistenceController.container.viewContext
                    )
                ),
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: appDayOfWeekRepository,
                    context: persistenceController.container.viewContext
                )
            )
        case "ZipCode":
            EnterZipCodeView(
                appDayOfWeekViewModel: appDayOfWeekViewModel,
                allEnteredLocationsViewModel: AllEnteredLocationsViewModel(
                    dataManager: pirateIslandDataManager
                ),
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: appDayOfWeekRepository,
                    context: viewContext
                )
            )
        case "Add or Edit Schedule/Open Mat":
            DaysOfWeekFormView(
                viewModel: appDayOfWeekViewModel,
                selectedIsland: $selectedIsland,
                selectedMatTime: .constant(nil),
                showReview: .constant(false)
            )
        case "Day of the Week":
            DayOfWeekSearchView(
                selectedIsland: $selectedIsland,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                region: $region,
                searchResults: $searchResults
            )
        case "Search Reviews":
            ViewReviewSearch(selectedIsland: $selectedIsland, enterZipCodeViewModel: appDayOfWeekViewModel.enterZipCodeViewModel)
        case "Submit a Review":
            GymMatReviewSelect(
                selectedIsland: $selectedIsland,
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: appDayOfWeekRepository,
                    context: viewContext
                )
            )
            .navigationTitle("Select Gym for Review")
            .navigationBarTitleDisplayMode(.inline)
        case "FAQ & Disclaimer":
            FAQnDisclaimerMenuView()
        default:
            EmptyView()
        }
    }
}

struct IslandMenu_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let profileViewModel = ProfileViewModel(viewContext: persistenceController.container.viewContext) // Create a profile view model for the preview

        return IslandMenu(persistenceController: persistenceController, isLoggedIn: .constant(true), profileViewModel: profileViewModel)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .previewDisplayName("Mat Menu Preview")
    }
}
