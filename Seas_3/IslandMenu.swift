//
//  IslandMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData

struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let subMenuItems: [String]?
}

struct IslandMenu: View {
    @StateObject private var locationManager = UserLocationMapViewModel()
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showAlert = false
    @State private var alertMessage = ""

    @State private var selectedIsland: PirateIsland? = nil

    // Use the shared PersistenceController instance
    let persistenceController = PersistenceController.shared
    let menuItems: [MenuItem] = [
        .init(title: "Search", subMenuItems: ["All Entered Locations", "Current Location", "Zip Code"]),
        .init(title: "Manage", subMenuItems: ["Add New Gym", "Update Existing Gyms", "Add or Edit Schedule/Open Mat"]),
        .init(title: "Review", subMenuItems: ["Add Gym/Open Mat Review"]),
    ]

    var body: some View {
        NavigationView {
            ZStack {
                GIFView(name: "flashing2")
                    .frame(width: 500, height: 450)
                    .offset(x: 100, y: -150)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Main Menu")
                        .font(.title)
                        .bold()
                        .padding(.top, 10)

                    ForEach(menuItems) { menuItem in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(menuItem.title)
                                .font(.headline)
                                .padding(.bottom, 20)

                            if let subMenuItems = menuItem.subMenuItems {
                                ForEach(subMenuItems, id: \.self) { subMenuItem in
                                    NavigationLink(destination: destinationView(for: subMenuItem)) {
                                        Text(subMenuItem)
                                            .foregroundColor(.blue)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, 10)
                                            .padding(.top, 5)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }

                    NavigationLink(destination: ContentView()) {
                        Text("ContentView")
                            .foregroundColor(.blue)
                            .padding(.leading, 0)
                            .padding(.top, 10)
                    }

                    NavigationLink(destination: FAQnDisclaimerMenuView()) {
                        Text("FAQ & Disclaimer")
                            .foregroundColor(.blue)
                            .padding(.top, 10)
                    }

                    // NavigationLink to pIslandScheduleView
                    NavigationLink(destination: pIslandScheduleView(viewModel: AppDayOfWeekViewModel(
                        selectedIsland: selectedIsland,
                        repository: AppDayOfWeekRepository(persistenceController: persistenceController)
                    ))) {
                        Text("View Gym Schedules")
                            .foregroundColor(.blue)
                            .padding(.top, 10)
                    }

                    // NavigationLink to AllpIslandScheduleView
                    NavigationLink(destination: AllpIslandScheduleView(viewModel: AppDayOfWeekViewModel(
                        repository: AppDayOfWeekRepository(persistenceController: persistenceController)
                    ))) {
                        Text("View ALL Mat Schedules")
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
            Alert(title: Text("Location Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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
            ConsolidatedIslandMapView()
        case "Zip Code":
            let viewModel = EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository(persistenceController: persistenceController),
                context: viewContext
            )
            EnterZipCodeView(viewModel: viewModel)
        case "Add or Edit Schedule/Open Mat":
            let viewModel = AppDayOfWeekViewModel(
                selectedIsland: selectedIsland,
                repository: AppDayOfWeekRepository(persistenceController: persistenceController)
            )
            DaysOfWeekFormView(viewModel: viewModel, selectedIsland: $selectedIsland)

        default:
            EmptyView()
        }
    }
}

// Closing bracket for the `IslandMenu` struct
struct IslandMenu_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        return IslandMenu()
            .environment(\.managedObjectContext, context)
            .previewDisplayName("Mat Menu Preview")
    }
}
