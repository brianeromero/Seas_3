//
//  AdminMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 10/26/24.
//

import Foundation
import SwiftUI

struct AdminMenu: View {
    @StateObject private var persistenceController: PersistenceController
    @StateObject private var appDayOfWeekRepository: AppDayOfWeekRepository
    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel

    init(persistenceController: PersistenceController,
         appDayOfWeekRepository: AppDayOfWeekRepository,
         enterZipCodeViewModel: EnterZipCodeViewModel,
         appDayOfWeekViewModel: AppDayOfWeekViewModel) {
        _persistenceController = StateObject(wrappedValue: persistenceController)
        _appDayOfWeekRepository = StateObject(wrappedValue: appDayOfWeekRepository)
        _enterZipCodeViewModel = StateObject(wrappedValue: enterZipCodeViewModel)
        _appDayOfWeekViewModel = StateObject(wrappedValue: appDayOfWeekViewModel)
    }
    

    let menuItems: [MenuItem] = [
        MenuItem(title: "Manage Users", subMenuItems: ["Reset User Verification", "Edit User", "Remove User", "Manual User Verification"], padding: 20),
        MenuItem(title: "Manage Gyms", subMenuItems: ["All Gyms", "ALL Gym Schedules", "ALL Mat Schedules"], padding: 15),
        MenuItem(title: "Manage Reviews", subMenuItems: ["View All Reviews", "Moderate Reviews"], padding: 20)
    ]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Admin Menu")
                    .font(.title)
                    .bold()

                ForEach(menuItems) { menuItem in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(menuItem.title)
                            .font(.headline)
                        
                        ForEach(menuItem.subMenuItems, id: \.self) { subMenuItem in
                            NavigationLink(destination: destinationView(for: subMenuItem)) {
                                Text(subMenuItem)
                                    .foregroundColor(.blue)
                                    .padding(.leading, 10)
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Admin Control Panel")
        }
    }
    
    @ViewBuilder
    private func destinationView(for option: String) -> some View {
        switch option {
        case IslandMenuOption.allLocations.rawValue:
            // TODO: Implement destination view
            EmptyView()
        case IslandMenuOption.currentLocation.rawValue:
            // TODO: Implement destination view
            EmptyView()
        case "Reset User Verification":
            ResetUserVerificationView()
        case "Manual User Verification":
            ManuallyVerifyUser()
        case "All Gyms":
            ContentView(persistenceController: persistenceController)
        case "ALL Gym Schedules":
            pIslandScheduleView(viewModel: appDayOfWeekViewModel)
        case "ALL Mat Schedules":
            AllpIslandScheduleView(
                viewModel: appDayOfWeekViewModel,
                persistenceController: persistenceController,
                enterZipCodeViewModel: enterZipCodeViewModel
            )
        default:
            EmptyView()
        }
    }
}

// Mock classes for previews
class MockAppDayOfWeekViewModel: AppDayOfWeekViewModel {
    convenience init() {
        let mockRepository = MockAppDayOfWeekRepository(persistenceController: PersistenceController.shared)
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(
            repository: mockRepository,
            context: PersistenceController.shared.container.viewContext
        )
        self.init(repository: mockRepository, enterZipCodeViewModel: mockEnterZipCodeViewModel)
        // Mock initialization
    }
}

// PreviewProvider for Canvas preview
struct AdminMenu_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared
        let appDayOfWeekRepository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let enterZipCodeViewModel = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            context: persistenceController.container.viewContext
        )
        let appDayOfWeekViewModel = AppDayOfWeekViewModel(
            repository: appDayOfWeekRepository,
            enterZipCodeViewModel: enterZipCodeViewModel
        )
        
        AdminMenu(persistenceController: persistenceController,
                  appDayOfWeekRepository: appDayOfWeekRepository,
                  enterZipCodeViewModel: enterZipCodeViewModel,
                  appDayOfWeekViewModel: appDayOfWeekViewModel)
            .environmentObject(persistenceController)
    }
}
