//
//  IslandMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let subMenuItems: [String]?
}

struct IslandMenu: View {
    @StateObject private var locationManager = LocationManager()
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showAlert = false
    @State private var alertMessage = ""

    let menuItems: [MenuItem] = [
        MenuItem(title: "Search For Gyms/ Open Mats By", subMenuItems: ["Day of Week", "All Entered Locations", "Near Me (use current location)", "Enter Zip Code"]),
        MenuItem(title: "Manage Gyms", subMenuItems: ["Add New Gym", "Update Existing Gyms", "Add/Edit Class or Open Mat"]),
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
                                            .fixedSize(horizontal: false, vertical: true) // Allow multiline text to wrap
                                            .frame(maxWidth: .infinity, alignment: .leading) // Align text to the left
                                    }
                                    .padding(.leading, 10) // Adjusted padding to align all links to the left
                                    .padding(.top, 5) // Add top padding for spacing between items
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }

                    NavigationLink(destination: ContentView()) {
                        Text("ContentView")
                            .foregroundColor(.blue)
                            .padding(.leading, 0) // Adjusted padding to align all links to the left
                            .padding(.top, 10) // Add some top padding to separate from menu items
                    }

                    NavigationLink(destination: FAQnDisclaimerMenuView()) {
                        Text("FAQ & Disclaimer")
                            .foregroundColor(.blue)
                            .padding(.leading, 0) // Adjusted padding to align all links to the left
                    }
                    .padding(.top, 10) // Add some top padding to separate from menu items
                }
                .padding(.horizontal, 20)
                .navigationBarTitle("Welcome to Mat_Finder", displayMode: .inline)
                .padding(.leading, 50) // Adjusted leading padding to move content closer to the left edge
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
        case "Add New Gym":
            AddNewIsland()
        case "Update Existing Gyms":
            EditExistingIslandList()
        case "All Entered Locations":
            AllEnteredLocations()
        case "Near Me (use current location)":
            ConsolidatedIslandMapView()
        case "Enter Zip Code":
            EnterZipCodeView()
        case "Add/Edit Class or Open Mat":
            DaysOfWeekFormView(viewModel: AppDayOfWeekViewModel())
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
