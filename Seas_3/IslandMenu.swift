// IslandMenu.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import MapKit



struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let subMenuItems: [String]?
}
struct IslandMenu: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @StateObject private var locationManager = UserLocationMapViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedAppDayOfWeek: AppDayOfWeek? = nil // Add this
    @State private var region: MKCoordinateRegion = MKCoordinateRegion() // Add this
    @State private var searchResults: [PirateIsland] = [] // Add this

    // Initialize the repository and data manager
    private var appDayOfWeekRepository: AppDayOfWeekRepository {
        return AppDayOfWeekRepository(persistenceController: PersistenceController.shared)
    }
    
    private var pirateIslandDataManager: PirateIslandDataManager {
        return PirateIslandDataManager(viewContext: viewContext)
    }

    @State private var appDayOfWeekViewModel: AppDayOfWeekViewModel?

    let menuItems: [MenuItem] = [
        .init(title: "Search Gym Entries By", subMenuItems: ["All Locations", "Current Location", "ZipCode", "Day of the Week"]),
        .init(title: "Manage Gyms Entries", subMenuItems: ["Add New Gym", "Update Existing Gyms", "Add or Edit Schedule/Open Mat"]),
        .init(title: "Reviews", subMenuItems: ["Search Reviews", "Submit a Review"]),
        .init(title: "FAQ", subMenuItems: ["FAQ & Disclaimer"])
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                GIFView(name: "flashing2")
                    .frame(width: 500, height: 450)
                    .offset(x: 100, y: -150)

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

                    NavigationLink(destination: ContentView()) {
                        Text("All Gyms")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .padding(.leading, 0)
                            .padding(.top, 10)
                    }

                    if let viewModel = appDayOfWeekViewModel {
                        NavigationLink(destination: pIslandScheduleView(viewModel: viewModel)) {
                            Text("ALL Gym Schedules")
                                .font(.footnote)
                                .foregroundColor(.blue)
                                .padding(.top, 10)
                        }
                    } else {
                        Text("Loading...")
                    }

                    if let viewModel = appDayOfWeekViewModel {
                        NavigationLink(destination: AllpIslandScheduleView(
                            viewModel: viewModel,
                            persistenceController: PersistenceController.shared,
                            enterZipCodeViewModel: EnterZipCodeViewModel(
                                repository: appDayOfWeekRepository,
                                context: viewContext
                            )
                        )) {
                            Text("ALL Mat Schedules")
                                .font(.footnote)
                                .foregroundColor(.blue)
                                .padding(.top, 10)
                        }
                    } else {
                        Text("Loading...")
                    }
                }
                .padding(.horizontal, 20)
                .navigationBarTitle("Welcome to Mat_Finder", displayMode: .inline)
                .padding(.leading, 50)
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
            print("Initializing appDayOfWeekViewModel")
            let repository = AppDayOfWeekRepository(persistenceController: PersistenceController.shared)
            let enterZipCodeViewModel = EnterZipCodeViewModel(
                repository: repository,
                context: viewContext
            )
            appDayOfWeekViewModel = AppDayOfWeekViewModel(
                selectedIsland: nil,
                repository: repository,
                enterZipCodeViewModel: enterZipCodeViewModel
            )
        }
    }

    @ViewBuilder
    private func destinationView(for menuItem: String) -> some View {
        switch menuItem {
        case "Add New Gym":
            AddNewIsland(viewModel: PirateIslandViewModel(context: viewContext))
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
                        context: viewContext
                    )
                )
            )
        case "ZipCode":
            if let viewModel = appDayOfWeekViewModel {
                EnterZipCodeView(
                    appDayOfWeekViewModel: viewModel,
                    allEnteredLocationsViewModel: AllEnteredLocationsViewModel(
                        dataManager: pirateIslandDataManager
                    ),
                    enterZipCodeViewModel: EnterZipCodeViewModel(
                        repository: appDayOfWeekRepository,
                        context: viewContext
                    )
                )
            } else {
                Text("Loading...")
            }

        case "Add or Edit Schedule/Open Mat":
            if let viewModel = appDayOfWeekViewModel {
                DaysOfWeekFormView(
                    viewModel: viewModel,
                    selectedIsland: $selectedIsland,
                    selectedMatTime: .constant(nil)
                )
            } else {
                Text("Loading...")
            }
        case "Day of the Week":
            DayOfWeekSearchView(
                selectedIsland: $selectedIsland,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                region: $region,
                searchResults: $searchResults
            )
        case "Search Reviews":
            if let viewModel = appDayOfWeekViewModel {
                ViewReviewSearch(selectedIsland: $selectedIsland, enterZipCodeViewModel: viewModel.enterZipCodeViewModel)
            } else {
                Text("Loading...") // Placeholder while the view model is not yet ready
            }
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
        let context = persistenceController.container.viewContext

        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let enterZipCodeViewModel = EnterZipCodeViewModel(repository: repository, context: context)
        let appDayOfWeekViewModel = AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: repository,
            enterZipCodeViewModel: enterZipCodeViewModel
        )

        return IslandMenu()
            .environment(\.managedObjectContext, context)
            .environmentObject(appDayOfWeekViewModel)
            .previewDisplayName("Mat Menu Preview")
    }
}
