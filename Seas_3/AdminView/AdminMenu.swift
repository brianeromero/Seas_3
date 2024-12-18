//
//  AdminMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 10/26/24.
//

import SwiftUI
import GoogleMobileAds

struct AdminMenu: View {
    @Environment(\.persistenceController) private var persistenceController
    private var appDayOfWeekRepository: AppDayOfWeekRepository
    let firestoreManager = FirestoreManager.shared

    
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
        MenuItem(title: "Manage Reviews", subMenuItems: ["View All Reviews", "Moderate Reviews"], padding: 20),
        MenuItem(title: "Delete Record", subMenuItems: ["Delete Record"], padding: 20)
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
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
                
                Spacer()
                
                // Sign Out Button
                NavigationLink(destination: LoginView(
                    islandViewModel: PirateIslandViewModel(persistenceController: persistenceController),
                    isSelected: .constant(.login),
                    navigateToAdminMenu: .constant(false),
                    isLoggedIn: .constant(false)
                )) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }

                BannerView() // Ad banner
            }
            .padding()
            .navigationTitle("Admin Control Panel")
        }
    }
    
    @ViewBuilder
    private func destinationView(for option: String) -> some View {
        switch option {
        case IslandMenuOption.allLocations.rawValue:
            EmptyView() // Placeholder
        case IslandMenuOption.currentLocation.rawValue:
            EmptyView() // Placeholder
        case "Reset User Verification":
            ResetUserVerificationView()
        case "Manual User Verification":
            ManuallyVerifyUser()
        case "All Gyms":
            ContentView(persistenceController: persistenceController)
        case "ALL Gym Schedules":
            pIslandScheduleView(viewModel: appDayOfWeekViewModel)
        case "ALL Mat Schedules":
            AllpIslandScheduleView(viewModel: appDayOfWeekViewModel, enterZipCodeViewModel: enterZipCodeViewModel)
                .environment(\.persistenceController, PersistenceController.shared)
        case "Delete Record":
            DeleteRecordView(coreDataContext: persistenceController.container.viewContext, firestoreManager: firestoreManager)
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
