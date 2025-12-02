//
//  AdminMenu.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/26/24.
//

import SwiftUI
import GoogleMobileAds
import FirebaseAuth

// MARK: - View Definition
struct AdminMenu: View {
    // MARK: - Environment Variables
    @Environment(\.persistenceController) private var persistenceController
    @EnvironmentObject var authenticationState: AuthenticationState

    // MARK: - State Variables
    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel

    private var firestoreManager: FirestoreManager { FirestoreManager.shared }
    private let appDayOfWeekRepository: AppDayOfWeekRepository

    // MARK: - Initialization
    init() {
        let persistenceController = PersistenceController.shared
        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let enterZipCodeVM = EnterZipCodeViewModel(
            repository: repository,
            persistenceController: persistenceController
        )
        self.appDayOfWeekRepository = repository
        self._enterZipCodeViewModel = StateObject(wrappedValue: enterZipCodeVM)
        self._appDayOfWeekViewModel = StateObject(
            wrappedValue: AppDayOfWeekViewModel(repository: repository, enterZipCodeViewModel: enterZipCodeVM)
        )
    }

    // MARK: - Enum for Menu Sections
    enum AdminMenuSection: String, CaseIterable, Identifiable {
        case users = "Manage Users"
        case gyms = "Manage Gyms"
        case reviews = "Manage Reviews"
        case deletion = "Data Management"
        case signout = "Account"

        var id: String { rawValue }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Admin Control Panel")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(Color(uiColor: .systemGray6))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Users Section
                    sectionHeader("Manage Users")
                    menuLink("Reset User Verification", destination: ResetUserVerificationView())
                    menuLink("Edit User", destination: EmptyView())
                    menuLink("Remove User", destination: EmptyView())
                    menuLink("Manual User Verification", destination: ManuallyVerifyUser())
                    menuLink("Delete User from Local Database", destination: DeleteUserView(coreDataContext: persistenceController.container.viewContext))

                    divider()

                    // Gyms Section
                    sectionHeader("Manage Gyms")
                    menuLink("All Gyms", destination: ContentView(persistenceController: persistenceController))
                    menuLink("ALL Gym Schedules", destination: pIslandScheduleView(viewModel: appDayOfWeekViewModel))
                    menuLink("ALL Mat Schedules", destination: AllpIslandScheduleView(
                        viewModel: appDayOfWeekViewModel,
                        enterZipCodeViewModel: enterZipCodeViewModel
                    )
                    .environment(\.persistenceController, PersistenceController.shared))

                    divider()

                    // Reviews Section ✅ Updated — only AllReviewsView implemented
                    sectionHeader("Manage Reviews")
                    menuLink("View All Reviews", destination: AllReviewsView())
                    menuLink("Moderate Reviews (Coming Soon)", destination:
                        Text("Moderation tools coming soon.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding()
                    )

                    divider()

                    // Deletion Section
                    sectionHeader("Data Management")
                    menuLink("Delete Gym Record", destination: DeleteRecordView(
                        coreDataContext: persistenceController.container.viewContext,
                        firestoreManager: firestoreManager
                    ))
                    menuLink("Delete AppDayOfWeek Record", destination: DeleteAppDayOfWeekRecordView(
                        coreDataContext: persistenceController.container.viewContext,
                        firestoreManager: firestoreManager
                    ))
                    menuLink("Delete MatTime Record", destination: DeleteMatTimeRecordView(
                        coreDataContext: persistenceController.container.viewContext,
                        firestoreManager: firestoreManager
                    ))

                    divider()

                    // Sign Out Section
                    sectionHeader("Account")
                    Button(action: signOut) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.leading, 20)
                    }
                }
                .padding(.top, 10)
            }
            .background(Color(uiColor: .systemBackground))

            BannerView()
                .frame(height: 50) // adjust the height as needed
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - View Builders
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.gray)
            .padding(.leading, 20)
            .padding(.top, 20)
    }

    private func menuLink<Destination: View>(_ label: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: "chevron.right.circle")
                    .foregroundColor(.accentColor)
                    .frame(width: 25)
                Text(label)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.leading, 20)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func divider() -> some View {
        Divider()
            .padding(.leading, 20)
            .padding(.top, 5)
    }

    // MARK: - Sign Out Logic
    private func signOut() {
        authenticationState.logout {
            print("✅ User signed out successfully")
        }
    }
}
