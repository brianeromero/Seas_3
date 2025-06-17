//
//  AdminMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 10/26/24.
//

import SwiftUI
import GoogleMobileAds
import FirebaseAuth


struct AdminMenu: View {
    @Environment(\.persistenceController) private var persistenceController
    @EnvironmentObject var authenticationState: AuthenticationState
    private var appDayOfWeekRepository: AppDayOfWeekRepository
    private var firestoreManager: FirestoreManager {
        FirestoreManager.shared
    }

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
        MenuItem(title: "Manage Users", subMenuItems: ["Reset User Verification", "Edit User", "Remove User", "Manual User Verification", "Delete User from Local Database"], padding: 20),
        MenuItem(title: "Manage Gyms", subMenuItems: ["All Gyms", "ALL Gym Schedules", "ALL Mat Schedules"], padding: 15),
        MenuItem(title: "Manage Reviews", subMenuItems: ["View All Reviews", "Moderate Reviews"], padding: 20),
        MenuItem(title: "Delete Gym Record", subMenuItems: ["Delete Gym Record"], padding: 20),
        MenuItem(title: "Delete AppDayOfWeek Record", subMenuItems: ["Delete AppDayOfWeek Record"], padding: 20),
        MenuItem(title: "Manage MatTimes", subMenuItems: ["Delete MatTime Record"], padding: 20),
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(menuItems) { menuItem in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(menuItem.title)
                            .font(.headline)
                            .foregroundColor(.primary) // Adaptive text color
                        
                        ForEach(menuItem.subMenuItems, id: \.self) { subMenuItem in
                            NavigationLink(destination: destinationView(for: subMenuItem)) {
                                Text(subMenuItem)
                                    .foregroundColor(.accentColor) // Adaptive accent color for links
                                    .padding(.leading, 10)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Sign Out Button
                Button(action: signOut) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                BannerView() // Ad banner
                    .padding(.top, 10) // Add some spacing above the banner
            }
            .padding()
            .navigationTitle("Admin Control Panel")
            .background(Color(uiColor: .systemBackground)) // Ensure the background adapts
            .ignoresSafeArea() // Extend background to safe areas
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
            // Ensure ContentView can also handle dark mode
            ContentView(persistenceController: persistenceController)
        case "ALL Gym Schedules":
            // Ensure pIslandScheduleView can also handle dark mode
            pIslandScheduleView(viewModel: appDayOfWeekViewModel)
        case "ALL Mat Schedules":
            // Ensure AllpIslandScheduleView can also handle dark mode
            AllpIslandScheduleView(viewModel: appDayOfWeekViewModel, enterZipCodeViewModel: enterZipCodeViewModel)
                .environment(\.persistenceController, PersistenceController.shared)
        case "Delete Gym Record":
            // Ensure DeleteRecordView can also handle dark mode
            DeleteRecordView(coreDataContext: persistenceController.container.viewContext, firestoreManager: firestoreManager)
        case "Delete User from Local Database":
            // Ensure DeleteUserView can also handle dark mode
            DeleteUserView(coreDataContext: persistenceController.container.viewContext)
        case "Delete AppDayOfWeek Record":
            // Ensure DeleteAppDayOfWeekRecordView can also handle dark mode
            DeleteAppDayOfWeekRecordView(coreDataContext: persistenceController.container.viewContext, firestoreManager: firestoreManager)
        case "Delete MatTime Record":
            // Ensure DeleteMatTimeRecordView can also handle dark mode
            DeleteMatTimeRecordView(coreDataContext: persistenceController.container.viewContext, firestoreManager: firestoreManager)
        default:
            EmptyView()
        }
    }

    private func signOut() {
        authenticationState.logout {
            print("User signed out successfully")
        }
    }
}
