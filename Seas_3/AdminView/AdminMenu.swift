//
//  AdminMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 10/26/24.
//

import Foundation
import SwiftUI

struct AdminMenu: View {
    @Environment(\.persistenceController) private var persistenceController
    private var appDayOfWeekRepository: AppDayOfWeekRepository
    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel

    init() {
        let persistenceController = PersistenceController.shared
        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        
        let enterZipCodeVM = EnterZipCodeViewModel(repository: repository, persistenceController: persistenceController)
        
        self.appDayOfWeekRepository = repository
        self._enterZipCodeViewModel = StateObject(wrappedValue: enterZipCodeVM)
        self._appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(repository: repository, enterZipCodeViewModel: enterZipCodeVM))
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
            EmptyView() // Placeholder until implemented
        case IslandMenuOption.currentLocation.rawValue:
            EmptyView() // Placeholder until implemented
        case "Reset User Verification":
            ResetUserVerificationView()
        case "Manual User Verification":
            ManuallyVerifyUser()
        case "All Gyms":
            ContentView(persistenceController: persistenceController)
        case "ALL Gym Schedules":
            // Ensure that the viewModel is passed correctly
            pIslandScheduleView(viewModel: appDayOfWeekViewModel)
        case "ALL Mat Schedules":
            AllpIslandScheduleView(viewModel: appDayOfWeekViewModel, enterZipCodeViewModel: enterZipCodeViewModel)
                .environment(\.persistenceController, PersistenceController.shared)
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
            persistenceController: PersistenceController.shared
        )
        self.init(repository: mockRepository, enterZipCodeViewModel: mockEnterZipCodeViewModel)
        // Mock initialization
    }
}

// PreviewProvider for Canvas preview
struct AdminMenu_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        
        return NavigationView {
            AdminMenu()
                .environment(\.persistenceController, persistenceController)
                .environmentObject(AuthenticationState())
        }
    }
}
