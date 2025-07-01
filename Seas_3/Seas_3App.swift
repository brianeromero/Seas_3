import SwiftUI
import Foundation // Make sure Foundation is imported for Date() and NSLog
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignInSwift
import GoogleSignIn
import os.log // Assuming you're still using os_log
import FirebaseCore
import FirebaseAuth // Assuming you need this for AuthViewModel.shared
import FirebaseFirestore // Assuming you need this for Firestore



@main
struct Seas_3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var selectedTabIndex: LoginViewSelection = .login

    // MARK: - Instantiate AllEnteredLocationsViewModel here
    @StateObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    
    // ✅ Add AppDayOfWeekViewModel here
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    
    @StateObject var enterZipCodeViewModel: EnterZipCodeViewModel


    // Use an initializer to set up your @StateObject
    init() {
        _allEnteredLocationsViewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(
            dataManager: PirateIslandDataManager(viewContext: PersistenceController.shared.container.viewContext)
        ))

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil, // This 'nil' is for AppDayOfWeekViewModel's own 'selectedIsland' parameter
            repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
            enterZipCodeViewModel: EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository.shared,
                persistenceController: PersistenceController.shared
            )
        ))

        _enterZipCodeViewModel = StateObject(wrappedValue: EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: PersistenceController.shared
        ))

        setupGlobalErrorHandler()
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView(
                selectedTabIndex: $selectedTabIndex,
                appState: appDelegate.appState
            )
            // 👇 Inject all necessary view models into environment
            .environmentObject(appDelegate.authenticationState)
            .environmentObject(AuthViewModel.shared)
            .environmentObject(appDelegate.pirateIslandViewModel)
            .environmentObject(appDelegate.profileViewModel!)
            .environmentObject(allEnteredLocationsViewModel)
            .environmentObject(appDayOfWeekViewModel) // ✅ Inject here so it’s available app-wide
            .environmentObject(enterZipCodeViewModel) // Ensure this is also injected at the root
            .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext)
        }
    }

    private func setupGlobalErrorHandler() {
        NSSetUncaughtExceptionHandler { exception in
            NSLog("🔥 Uncaught Exception: %@", exception)
            if let reason = exception.reason {
                NSLog("🛑 Reason: %@", reason)
            }
        }
    }
}

struct AppRootView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var pirateIslandViewModel: PirateIslandViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @EnvironmentObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    
    // ✅ ADD THIS LINE: To make enterZipCodeViewModel available in this view's hierarchy
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @Binding var selectedTabIndex: LoginViewSelection
    @ObservedObject var appState: AppState

    @State private var navigationPath = NavigationPath()

    @State private var showInitialSplash = true

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if showInitialSplash {
                    PirateIslandView(appState: appState)
                        .onAppear {
                            print("AppRootView: Showing Initial Splash (PirateIslandView)")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeInOut(duration: 1)) {
                                    showInitialSplash = false
                                }
                            }
                        }
                } else if authenticationState.isAuthenticated {
                    DebugPrintView("AppRootView: AuthenticationState.isAuthenticated is TRUE. Displaying Authenticated Content.")

                    if authenticationState.navigateToAdminMenu {
                        AdminMenu()
                            .onAppear { print("AppRootView: AdminMenu has appeared.") }
                    } else {
                        IslandMenu2(
                            profileViewModel: profileViewModel,
                            navigationPath: $navigationPath
                        )
                        .onAppear { print("AppRootView: IslandMenu has appeared.") }
                    }
                } else {
                    DebugPrintView("AppRootView: AuthenticationState.isAuthenticated is FALSE. Displaying LoginView.")
                    LoginView(
                        islandViewModel: pirateIslandViewModel,
                        profileViewModel: profileViewModel,
                        isSelected: $selectedTabIndex,
                        navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                        isLoggedIn: $authenticationState.isLoggedIn,
                        navigationPath: $navigationPath
                    )
                    .onAppear { print("AppRootView: LoginView has appeared.") }
                }
            }
            .navigationDestination(for: AppScreen.self) { screen in
                AppRootDestinationView(screen: screen, navigationPath: $navigationPath)
                    .environmentObject(authenticationState)
                    .environmentObject(authViewModel)
                    .environmentObject(pirateIslandViewModel)
                    .environmentObject(profileViewModel)
                    .environmentObject(allEnteredLocationsViewModel)
                    .environmentObject(appDayOfWeekViewModel) // Inject here as well!
                    .environmentObject(enterZipCodeViewModel) // Ensure this is also injected
            }
        }
        .onChange(of: authenticationState.isAuthenticated) { oldValue, newValue in
            print("AppRootView onChange: authenticationState.isAuthenticated changed from \(oldValue) to \(newValue)")
            if !newValue {
                navigationPath = NavigationPath()
                print("DEBUG: AppRootView - Navigation path cleared (due to unauthenticated state).")
            }
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            print("⚠️ [AppRootView] navigationPath changed from \(oldPath) to \(newPath)")
        }
    }
}

struct AppRootDestinationView: View {
    let screen: AppScreen
    @Binding var navigationPath: NavigationPath

    @EnvironmentObject var authenticationState: AuthenticationState
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var pirateIslandViewModel: PirateIslandViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel

    @EnvironmentObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @EnvironmentObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - New State for AddNewIsland
    @State private var islandDetails = IslandDetails() // Initialize with default values


    var body: some View {
        switch screen {
        case .review(let islandIDString):
            if let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: islandIDString)!) {
                if let island = try? viewContext.existingObject(with: objectID) as? PirateIsland {
                    GymMatReviewView(localSelectedIsland: .constant(island))
                        .onAppear {
                            print("🧭 Navigating to screen: .review -> \(island.islandName ?? "Unknown")")
                        }
                } else {
                    Text("Error: Island not found for review.")
                }
            } else {
                Text("Error: Invalid Island ID for review.")
            }

        case .viewAllReviews(let islandIDString):
            if let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: islandIDString)!) {
                if let island = try? viewContext.existingObject(with: objectID) as? PirateIsland {
                    ViewReviewforIsland(
                        showReview: .constant(true),
                        selectedIsland: island,
                        navigationPath: $navigationPath
                    )
                } else {
                    Text("Error: Island not found for viewing reviews.")
                }
            } else {
                Text("Error: Invalid Island ID for viewing reviews.")
            }

        case .selectGymForReview:
            GymMatReviewSelect(selectedIsland: .constant(nil), navigationPath: $navigationPath)

        case .searchReviews:
            ViewReviewSearch(selectedIsland: .constant(nil), titleString: "Search Gym Reviews", navigationPath: $navigationPath)

        case .profile:
            ProfileView(
                profileViewModel: profileViewModel,
                authViewModel: authViewModel,
                selectedTabIndex: .constant(.login),
                setupGlobalErrorHandler: { }
            )
            .onAppear {
                print("🧭 Navigating to screen: .profile")
            }
            
        case .allLocations:
            AllEnteredLocations(
                viewModel: allEnteredLocationsViewModel,
                navigationPath: $navigationPath
            )
            .onAppear {
                print("🧭 Navigating to screen: .allLocations")
            }

        case .currentLocation:
            ConsolidatedIslandMapView(
                viewModel: appDayOfWeekViewModel,
                enterZipCodeViewModel: enterZipCodeViewModel,
                navigationPath: $navigationPath
            )
            .onAppear {
                print("🧭 Navigating to screen: .currentLocation (ConsolidatedIslandMapView)")
            }

        case .postalCode:
            // ✅ Replace the placeholder Text with EnterZipCodeView
            EnterZipCodeView(
                appDayOfWeekViewModel: appDayOfWeekViewModel,
                allEnteredLocationsViewModel: allEnteredLocationsViewModel,
                enterZipCodeViewModel: enterZipCodeViewModel
            )
            .onAppear {
                print("🧭 Navigating to screen: .postalCode (EnterZipCodeView)")
            }

        case .dayOfWeek:
            // ✅ Direct to DayOfWeekSearchView, now relying on environment objects
            DayOfWeekSearchView() // This is now correct!
                .onAppear {
                    print("🧭 Navigating to screen: .dayOfWeek (DayOfWeekSearchView)")
                }

        case .addNewGym:
            // ✅ CORRECTED: Remove explicit passing of EnvironmentObjects.
            // AddNewIsland should declare them as @EnvironmentObject and receive them automatically.
            AddNewIsland(
                // islandViewModel: pirateIslandViewModel, // REMOVED
                // profileViewModel: profileViewModel,     // REMOVED
                // authViewModel: authViewModel,           // REMOVED
                navigationPath: $navigationPath,
                islandDetails: $islandDetails // This is a @Binding and needs to be passed explicitly
            )
            .onAppear {
                print("🧭 Navigating to screen: .addNewGym (AddNewIsland)")
            }

        case .updateExistingGyms:
            // ✅ CRITICAL: Pass the navigationPath binding here
            EditExistingIslandList(navigationPath: $navigationPath) // <--- THIS IS THE LINE TO UPDATE
                .onAppear {
                    print("🧭 Navigating to screen: .updateExistingGyms (EditExistingIslandList)")
                }

        case .editExistingIsland(let islandIDString):
            if let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: islandIDString)!) {
                if let island = try? viewContext.existingObject(with: objectID) as? PirateIsland {
                    // ✅ Assuming EditExistingIsland now uses @EnvironmentObject for these
                    EditExistingIsland(
                        island: island
                        // REMOVED explicit passing of islandViewModel, profileViewModel, authViewModel
                        // as they should be injected via environment if needed.
                        // If EditExistingIsland *still* requires these as direct parameters,
                        // you will need to add them back here and to EditExistingIsland's init.
                    )
                    .onAppear {
                        print("🧭 Navigating to screen: .editExistingIsland -> \(island.islandName ?? "Unknown")")
                    }
                } else {
                    Text("Error: Island not found for editing.")
                }
            } else {
                Text("Error: Invalid Island ID for editing.")
            }

        case .addOrEditScheduleOpenMat:
            Text("Add or Edit Schedule Open Mat Screen - To be implemented")

        case .faqDisclaimer:
            Text("FAQ / Disclaimer Screen - To be implemented")
        }
    }
}



// Optional: Extension for injecting PersistenceController via Environment
struct PersistenceControllerKey: EnvironmentKey {
    static var defaultValue: PersistenceController { PersistenceController.shared }
}

extension EnvironmentValues {
    var persistenceController: PersistenceController {
        get { self[PersistenceControllerKey.self] }
        set { self[PersistenceControllerKey.self] = newValue }
    }
}
