import SwiftUI
import Foundation
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignInSwift
import GoogleSignIn
import os.log
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

private struct IsRestrictedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

@main
struct Mat_FinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var selectedTabIndex: LoginViewSelection = .login
    @StateObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @StateObject var enterZipCodeViewModel: EnterZipCodeViewModel

    init() {
        _allEnteredLocationsViewModel = StateObject(
            wrappedValue: AllEnteredLocationsViewModel(
                dataManager: PirateIslandDataManager(
                    viewContext: PersistenceController.shared.container.viewContext
                )
            )
        )

        _appDayOfWeekViewModel = StateObject(
            wrappedValue: AppDayOfWeekViewModel(
                selectedIsland: nil,
                repository: AppDayOfWeekRepository.shared,
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository.shared,
                    persistenceController: PersistenceController.shared
                )
            )
        )

        _enterZipCodeViewModel = StateObject(
            wrappedValue: EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository.shared,
                persistenceController: PersistenceController.shared
            )
        )

        setupGlobalErrorHandler()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                selectedTabIndex: $selectedTabIndex,
                appState: appDelegate.appState
            )
            .environmentObject(appDelegate.authenticationState)
            .environmentObject(AuthViewModel.shared)
            .environmentObject(appDelegate.pirateIslandViewModel)
            .environmentObject(appDelegate.profileViewModel!)
            .environmentObject(allEnteredLocationsViewModel)
            .environmentObject(appDayOfWeekViewModel)
            .environmentObject(enterZipCodeViewModel)
            .environment(\.managedObjectContext,
                         appDelegate.persistenceController.container.viewContext)
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

    // Global Toast
    @State private var globalShowToast = false
    @State private var globalToastMessage = ""
    @State private var globalToastType: ToastView.ToastType = .success

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                // 0. Initial splash screen
                if showInitialSplash {
                    PirateIslandView(appState: appState)
                        .onAppear {
                            print("AppRootView: Showing Initial Splash")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeInOut(duration: 1)) {
                                    showInitialSplash = false
                                }
                            }
                        }

                // 1. Signed-in user → UNRESTRICTED IslandMenu2
                } else if authenticationState.isAuthenticated {
                    IslandMenu2(
                        profileViewModel: profileViewModel,
                        navigationPath: $navigationPath
                    )
                    .environment(\.isRestricted, false)
                    .onAppear { print("AppRootView: IslandMenu2 (UNRESTRICTED) appeared") }

                // 2. Not signed-in → RESTRICTED IslandMenu2
                } else {
                    IslandMenu2(
                        profileViewModel: profileViewModel,
                        navigationPath: $navigationPath
                    )
                    .environment(\.isRestricted, true)
                    .onAppear { print("AppRootView: IslandMenu2 (RESTRICTED) appeared") }
                }
            }

            // Admin Navigation
            .navigationDestination(isPresented: $authenticationState.navigateToAdminMenu) {
                AdminMenu()
                    .environmentObject(authenticationState)
                    .environmentObject(authViewModel)
                    .environmentObject(pirateIslandViewModel)
                    .environmentObject(profileViewModel)
                    .environmentObject(allEnteredLocationsViewModel)
                    .environmentObject(appDayOfWeekViewModel)
                    .environmentObject(enterZipCodeViewModel)
                    .onAppear { print("✅ Navigated to AdminMenu") }
            }

            // AppScreen Navigation
            .navigationDestination(for: AppScreen.self) { screen in
                AppRootDestinationView(
                    screen: screen,
                    navigationPath: $navigationPath,
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
        .onChange(of: navigationPath) { old, new in
            print("⚠️ navigationPath changed from \(old) to \(new)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ShowToast"))) { notification in
            guard let userInfo = notification.userInfo,
                  let message = userInfo["message"] as? String,
                  let typeRaw = userInfo["type"] as? String,
                  let type = ToastView.ToastType(rawValue: typeRaw)
            else { return }

            withAnimation {
                globalToastMessage = message
                globalToastType = type
                globalShowToast = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { globalShowToast = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("HideToast"))) { _ in
            withAnimation { globalShowToast = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userLoggedOut)) { _ in
            withAnimation {
                authenticationState.isAuthenticated = false
                authenticationState.didJustCreateAccount = false
                navigationPath = NavigationPath()
                selectedTabIndex = .islandMenu2
                AppRouter.shared.currentScreen = .main
            }
        }


        
        .onReceive(NotificationCenter.default.publisher(for: .navigateHome)) { _ in
            print("🧭 AppRootView received navigateHome")

            navigationPath = NavigationPath()
            AppRouter.shared.currentScreen = .main
        }



        // Global toast overlay
        .overlay(
            Group {
                if globalShowToast {
                    ToastView(message: globalToastMessage, type: globalToastType)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: globalShowToast)
                        .offset(y: 50)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .top)
            .ignoresSafeArea()
        )
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("All Gyms")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }

            
        case .profile:
            ProfileView(
                profileViewModel: profileViewModel,
                authViewModel: authViewModel,
                selectedTabIndex: .constant(.login),
                navigationPath: $navigationPath,
                setupGlobalErrorHandler: { }
            )
            .environmentObject(authenticationState)

            .onAppear {
                print("🧭 Navigating to screen: .profile")
            }
            
        case .allLocations:
            AllEnteredLocations(
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
            AddNewIsland(
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
            DaysOfWeekFormView(
                appDayOfWeekViewModel: appDayOfWeekViewModel,
                selectedIsland: .constant(nil),
                selectedMatTime: .constant(nil),
                showReview: .constant(false)
            )
            .onAppear {
                print("🧭 Navigating to screen: .addOrEditScheduleOpenMat (DaysOfWeekFormView)")
            }
            
        case .faqDisclaimer:
            FAQnDisclaimerMenuView()
                .onAppear {
                    print("🧭 Navigating to screen: .faqDisclaimer (FAQnDisclaimerMenuView)")
                }
        
        case .aboutus:
            AboutUsView()
                .onAppear {
                    print("🧭 Navigating to screen: .aboutus (AboutUsView)")
                }

        case .disclaimer:
            DisclaimerView()
                .onAppear {
                    print("🧭 Navigating to screen: .disclaimer (DisclaimerView)")
                }

        case .faq:
            FAQView()
                .onAppear {
                    print("🧭 Navigating to screen: .faq (FAQView)")
                }
        case .viewSchedule(let islandIDString):
            if let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(
                forURIRepresentation: URL(string: islandIDString)!
            ) {
                if let island = try? viewContext.existingObject(with: objectID) as? PirateIsland {

                    IslandScheduleView(
                        viewModel: appDayOfWeekViewModel,
                        pIsland: island
                    )
                    .onAppear {
                        print("🧭 Navigating to screen: .viewSchedule -> \(island.islandName ?? "Unknown")")
                    }

                } else {
                    Text("Error: Island not found for schedule.")
                }
            } else {
                Text("Error: Invalid Island ID for schedule.")
            }
        case .login:
            LoginView(
                islandViewModel: pirateIslandViewModel,
                profileViewModel: profileViewModel,
                isSelected: .constant(.login),
                navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                isLoggedIn: .constant(authenticationState.isAuthenticated),
                navigationPath: $navigationPath  // <-- added this
            )
            .environmentObject(authViewModel)
            .environmentObject(pirateIslandViewModel)
            .environmentObject(profileViewModel)
            .onAppear {
                print("🧭 Navigating to screen: .login (LoginParentView)")
            }
        }
    }
}


// Optional: Extension for injecting PersistenceController via Environment
struct PersistenceControllerKey: EnvironmentKey {
    static var defaultValue: PersistenceController {
        MainActor.assumeIsolated {
            PersistenceController.shared
        }
    }
}

extension EnvironmentValues {
    var persistenceController: PersistenceController {
        get { self[PersistenceControllerKey.self] }
        set { self[PersistenceControllerKey.self] = newValue }
    }
    
    var isRestricted: Bool {
        get { self[IsRestrictedKey.self] }
        set { self[IsRestrictedKey.self] = newValue }
    }
    
}
