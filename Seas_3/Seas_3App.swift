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
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @Binding var selectedTabIndex: LoginViewSelection
    @ObservedObject var appState: AppState

    @State private var navigationPath = NavigationPath()
    @State private var showInitialSplash = true
    
    // --- Global Toast State Variables ---
    @State private var globalShowToast: Bool = false
    @State private var globalToastMessage: String = ""
    @State private var globalToastType: ToastView.ToastType = .success
    // --- END Global Toast State Variables ---

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
                AppRootDestinationView(
                    screen: screen,
                    navigationPath: $navigationPath,
                    // Pass bindings down
                    globalShowToast: $globalShowToast,
                    globalToastMessage: $globalToastMessage,
                    globalToastType: $globalToastType
                )
                .environmentObject(authenticationState)
                .environmentObject(authViewModel)
                .environmentObject(pirateIslandViewModel)
                .environmentObject(profileViewModel)
                .environmentObject(allEnteredLocationsViewModel)
                .environmentObject(appDayOfWeekViewModel)
                .environmentObject(enterZipCodeViewModel)
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
        // ✅ This is where the toast *listener* and *display logic* should live
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowToast"))) { notification in
            if let userInfo = notification.userInfo,
               let message = userInfo["message"] as? String,
               let typeString = userInfo["type"] as? String,
               let type = ToastView.ToastType(rawValue: typeString) {

                self.globalToastMessage = message
                self.globalToastType = type
                self.globalShowToast = true

                // Auto-hide the toast after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // Adjust duration as needed
                    withAnimation {
                        self.globalShowToast = false
                    }
                }
            }
        }
        // ✅ NOW, use the .overlay with your ToastView and position it here
        .overlay(
            Group {
                if globalShowToast {
                    ToastView(message: globalToastMessage, type: globalToastType)
                        .transition(.move(edge: .top).combined(with: .opacity)) // Or .opacity, or scale
                        .animation(.easeInOut(duration: 0.3), value: globalShowToast)
                        // This is where you control the position in AppRootView
                        // For 3/4 way down, you'll need to estimate the Y offset.
                        // A good starting point is to align to .top and push it down.
                        .offset(y: UIScreen.main.bounds.height * 0.3) // Example: Pushes it down 30% of screen height
                                                                   // Adjust multiplier (0.3) for desired height.
                                                                   // Or for 3/4 way down, it would be around 0.75 - height of toast itself.
                                                                   // Let's try 0.75 and then adjust slightly up.
                        // A more robust approach might involve GeometryReader to get precise height.
                }
            }
            // The alignment for the overlay itself. We want the ToastView to be aligned within the overlay frame.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Keep the frame, but offset the content inside
            .ignoresSafeArea(.all, edges: .all) // Allow toast to go over safe area
        )
    }
}


// Your AppRootDestinationView code remains mostly the same,
// as you're already passing the global toast bindings to it.
// Just ensure any child views that trigger a local toast *instead* of the global one
// use their own @State for that local toast, or if they intend to trigger the global,
// they would use the NotificationCenter to post it.

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
    
    // --- NEW: Bindings to receive toast state from AppRootView ---
    @Binding var globalShowToast: Bool
    @Binding var globalToastMessage: String
    @Binding var globalToastType: ToastView.ToastType
    // --- END NEW ---
    
    
    // MARK: - New State for AddNewIsland
    @State private var islandDetails = IslandDetails() // Initialize with default values
    
    // MARK: - New State for EditExistingIsland success toast
    // You can remove these if you are exclusively using the global toast now
    // @State private var showEditSuccessToast: Bool = false
    // @State private var editSuccessToastMessage: String = ""


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
                // profileViewModel: profileViewModel,      // REMOVED
                // authViewModel: authViewModel,            // REMOVED
                navigationPath: $navigationPath,
                islandDetails: $islandDetails // This is a @Binding and needs to be passed explicitly
            )
            .onAppear {
                print("🧭 Navigating to screen: .addNewGym (AddNewIsland)")
            }

        case .updateExistingGyms:
            // ✅ CRITICAL: Pass the navigationPath binding here
            EditExistingIslandList(
                navigationPath: $navigationPath,
                showGlobalToast: $globalShowToast,      // <-- Add this
                globalToastMessage: $globalToastMessage, // <-- Add this
                globalToastType: $globalToastType        // <-- Add this
            )
            .onAppear {
                print("🧭 Navigating to screen: .updateExistingGyms (EditExistingIslandList)")
            }

        case .editExistingIsland(let islandIDString):
            if let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: islandIDString)!) {
                if let island = try? viewContext.existingObject(with: objectID) as? PirateIsland {
                    // ✅ CRITICAL: Pass the global toast bindings from AppRootView
                    EditExistingIsland(
                        island: island,
                        showSuccessToast: $globalShowToast,       // Pass the global binding
                        successToastMessage: $globalToastMessage, // Pass the global binding
                        successToastType: $globalToastType        // Pass the global binding
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
