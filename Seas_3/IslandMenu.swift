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

    let menuItems: [MenuItem] = [
        MenuItem(title: "Search For Gyms/ Open Mats using", subMenuItems: ["Day of Week", "All Entered Locations", "Current Location", "Zip Code"]),
        MenuItem(title: "Manage Gyms", subMenuItems: ["Add New Gym", "Update Existing Gyms", "Add or Edit Schedule/Open Mat"]),
        MenuItem(title: "Reviews", subMenuItems: ["Add Gym/Open Mat Review"]),
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
                    NavigationLink(destination: pIslandScheduleView(viewModel: AppDayOfWeekViewModel(selectedIsland: selectedIsland))) {
                        Text("View Island Schedules")
                            .foregroundColor(.blue)
                            .padding(.top, 10)
                    }

                    // NavigationLink to AllpIslandScheduleView
                    NavigationLink(destination: AllpIslandScheduleView()) {
                        Text("View ALL Island Schedules")
                            .foregroundColor(.blue)
                            .padding(.top, 10)
                    }
                    
                    
                    // NavigationLink to MainLoginView
                    NavigationLink(destination: MainLoginView()) {
                        Text("Main Login")
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
            Logger.log("View appeared", view: "IslandMenu")
        }
    }

    @ViewBuilder
    private func destinationView(for menuItem: String) -> some View {
        switch menuItem {
        case "Day of Week":
            OpenMatsByDayOfWeekView()
        case "Add New Gym":
            AddNewIsland(viewModel: PirateIslandViewModel(context: viewContext))
        case "Update Existing Gyms":
            EditExistingIslandList()
        case "All Entered Locations":
            AllEnteredLocations(context: viewContext)
        case "Current Location":
            ConsolidatedIslandMapView()
        case "Zip Code":
            let viewModel = EnterZipCodeViewModel(context: viewContext)
            EnterZipCodeView(viewModel: viewModel)
        case "Add or Edit Schedule/Open Mat":
            DaysOfWeekFormView(viewModel: AppDayOfWeekViewModel(selectedIsland: selectedIsland), selectedIsland: $selectedIsland)
        default:
            EmptyView()
        }
    }
}

struct IslandMenu_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext
        
        let previewMenu = IslandMenu().environment(\.managedObjectContext, context)
        
        return Group {
            previewMenu.previewDisplayName("Island Menu Preview")
        }
    }
}

extension NSManagedObjectContext {
    static var preview: NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = PersistenceController.preview.container.persistentStoreCoordinator
        return context
    }
}
