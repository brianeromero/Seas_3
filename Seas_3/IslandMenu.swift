// IslandMenu.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData

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

    // Initialize the repository
    private var appDayOfWeekRepository: AppDayOfWeekRepository {
        return AppDayOfWeekRepository(persistenceController: PersistenceController.shared)
    }
    
    // Initialize the view model with the repository
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel

    init() {
        let persistenceController = PersistenceController.shared
        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)

        // Initialize the view model with required parameters
        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            persistenceController, // Remove extraneous argument label
            selectedIsland: nil,
            repository: repository
        ))
    }

    @Environment(\.managedObjectContext) private var viewContext

    let menuItems: [MenuItem] = [
        .init(title: "Search Gym Entries by", subMenuItems: ["All Entered Locations", "Current Location", "ZipCode", "Day Of Week"]),
        .init(title: "Manage Gyms Entries", subMenuItems: ["Add New Gym", "Update Existing Gyms", "Add or Edit Schedule/Open Mat"]),
        .init(title: "Gym Reviews", subMenuItems: ["Submit Gym/Open Mat Review"]),
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

                    NavigationLink(destination: pIslandScheduleView(viewModel: appDayOfWeekViewModel)) {
                        Text("ALL Gym Schedules")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .padding(.top, 10)
                    }

                    NavigationLink(destination: AllpIslandScheduleView(viewModel: appDayOfWeekViewModel, persistenceController: PersistenceController.shared)) {
                        Text("ALL Mat Schedules")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .padding(.top, 10)
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
            Logger.log("View appeared", view: "Main Menu")
        }
    }

    @ViewBuilder
    private func destinationView(for menuItem: String) -> some View {
        switch menuItem {
        case "Add New Gym":
            AddNewIsland(viewModel: PirateIslandViewModel(context: viewContext))
        case "Update Existing Gyms":
            EditExistingIslandList()
        case "All Entered Locations":
            AllEnteredLocations(context: viewContext)
        case "Current Location":
            ConsolidatedIslandMapView(viewModel: appDayOfWeekViewModel)
        case "ZipCode":
            EnterZipCodeView(viewModel: EnterZipCodeViewModel(
                repository: appDayOfWeekRepository, // Use the repository instance
                context: viewContext
            ))
        case "Add or Edit Schedule/Open Mat":
            DaysOfWeekFormView(
                viewModel: appDayOfWeekViewModel,
                selectedIsland: $selectedIsland,
                selectedMatTime: .constant(nil)
            )
        case "Day Of Week":
            DayOfWeekSearchView()
        case "Submit Gym/Open Mat Review":
            GymMatReviewSelect(selectedIsland: $selectedIsland)
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

        return IslandMenu()
            .environment(\.managedObjectContext, context)
            .previewDisplayName("Mat Menu Preview")
    }
}
