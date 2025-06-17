//
//  IslandMenu2.swift
//  Seas_3
//
//  Created by Brian Romero on 6/16/25.
//

import Foundation
import SwiftUI
import CoreData
import MapKit
import os

import OSLog // For os_log

// MARK: - View Definition
struct IslandMenu2: View {

    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss // Updated for iOS 15+
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel

    @State private var islandDetails: IslandDetails = IslandDetails()

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @StateObject private var locationManager = UserLocationMapViewModel()
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var searchResults: [PirateIsland] = []
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    let profileViewModel: ProfileViewModel
    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false

    // MARK: - Centralized ViewModel/Repository Instantiations
    private let appDayOfWeekRepository: AppDayOfWeekRepository
    private let enterZipCodeViewModelForAppDayOfWeek: EnterZipCodeViewModel
    private let enterZipCodeViewModelForReviews: EnterZipCodeViewModel
    private let pirateIslandViewModel: PirateIslandViewModel

    // Adjusted padding to match the visual layout in the image
    let menuLeadingPadding: CGFloat = 20

    // MARK: - Initialization
    init(profileViewModel: ProfileViewModel) {
        os_log("User logged in", log: IslandMenulogger)
        os_log("Initializing IslandMenu", log: IslandMenulogger)

        self.profileViewModel = profileViewModel

        let sharedPersistenceController = PersistenceController.shared
        self.appDayOfWeekRepository = AppDayOfWeekRepository(persistenceController: sharedPersistenceController)

        self.enterZipCodeViewModelForAppDayOfWeek = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )
        self.enterZipCodeViewModelForReviews = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )

        self.pirateIslandViewModel = PirateIslandViewModel(persistenceController: sharedPersistenceController)

        let localAppDayOfWeekRepository = self.appDayOfWeekRepository
        let localEnterZipCodeViewModel = self.enterZipCodeViewModelForAppDayOfWeek

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: localAppDayOfWeekRepository,
            enterZipCodeViewModel: localEnterZipCodeViewModel
        ))
    }

    // New Enum to represent all menu options
    enum IslandMenuOption: String, CaseIterable, Identifiable {
        var id: String { rawValue } // Conformance to Identifiable
        //case recentlyViewed = "Recently Viewed"
        //case more = "More" // This can be a "catch-all" or deeper menu if needed

        // Your existing "Mat_Finder" specific options, now integrated directly
        case profile = "Profile"
        case empty = ""
        case allLocations = "All Locations"
        case currentLocation = "Current Location"
        case postalCode = "Postal Code"
        case dayOfWeek = "Day of the Week"
        case addNewGym = "Add New Gym"
        case updateExistingGyms = "Update Existing Gyms"
        case addOrEditScheduleOpenMat = "Add or Edit Schedule/Open Mat"
        case searchReviews = "Search Reviews"
        case submitReview = "Submit a Review"
        case faqDisclaimer = "FAQ & Disclaimer"
        


        // Map menu options to SF Symbols based on the image
        var iconName: String {
            switch self {
            case .profile: return "person.crop.circle"
            //case .recentlyViewed: return "eye"
            //case .more: return "ellipsis.circle"

            // Mapping your existing menu items to icons
            case .empty: return ""
            case .allLocations: return "map"
            case .currentLocation: return "location.fill"
            case .postalCode: return "location.magnifyingglass"
            case .dayOfWeek: return "calendar"
            case .addNewGym: return "plus.circle"
            case .updateExistingGyms: return "rectangle.and.pencil.and.ellipsis"
            case .addOrEditScheduleOpenMat: return "calendar.badge.plus"
            case .searchReviews: return "text.magnifyingglass"
            case .submitReview: return "bubble.and.pencil"
            case .faqDisclaimer: return "questionmark.circle"

            }
        }

        // Determine if a divider should appear after this item
        var needsDivider: Bool {
            switch self {
            case .empty: return true
            case .dayOfWeek: return true
            case .addOrEditScheduleOpenMat: return true
            case .submitReview: return true
            default: return false
            }
        }

        // ✨ NEW: Property to hold header text for a divider
        var dividerHeaderText: String? {
            switch self {
            case .empty: return "Search By"
            case .dayOfWeek: return "Manage Entries"
            case .addOrEditScheduleOpenMat: return "Reviews"
            case .submitReview: return "FAQ"
            default: return nil
            }
        }
    }

    // Flattened menu items to match the image's layout
    let menuItemsFlat: [IslandMenuOption] = [
        .empty,
        //.recentlyViewed,
        //.more,
        .allLocations,
        .currentLocation,
        .postalCode,
        .dayOfWeek,
        .addNewGym,
        .updateExistingGyms,
        .addOrEditScheduleOpenMat,
        .searchReviews,
        .submitReview,
        .faqDisclaimer,
        
        .profile

    ]

    // MARK: - Body
    var body: some View {
        NavigationView { // Wrap with NavigationView for navigation links
            // We'll put the GIFView inside the VStack's background
            VStack(alignment: .leading, spacing: 0) { // Align content to the leading edge
                // Top Bar (Logo and Icons)
                HStack {
                    Spacer() // Push logo to the center
                    Text("Mat_Finder") // Placeholder for your logo/brand name
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary) // Automatically black in Light, white/light gray in Dark
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10) // Adjust top padding

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Render all menu items from menuItemsFlat
                        ForEach(menuItemsFlat) { option in
                            NavigationLink {
                                destinationView(for: option)
                            } label: {
                                HStack {
                                    Image(systemName: option.iconName)
                                        .font(option == .profile ? .title2 : .body) // Larger icon for Profile
                                        .frame(width: option == .profile ? nil : 25) // Fixed width for other icons
                                        .foregroundColor(option == .profile ? .blue : .secondary) // .secondary will adapt
                                    Text(option.rawValue)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary) // Automatically black in Light, white/light gray in Dark
                                    Spacer()
                                }
                                .padding(.vertical, 10) // Padding for each menu item
                                .padding(.leading, menuLeadingPadding)
                            }
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded {
                                        os_log("User tapped menu item: %@", log: IslandMenulogger, option.rawValue)
                                    }
                            )

                            // YOU ARE MISSING THIS BLOCK HERE!
                            // This checks if a divider is needed AND then if a header text exists for it.
                            if option.needsDivider {
                                Divider()
                                    .padding(.leading, menuLeadingPadding) // Indent divider

                                // ✨ THIS IS THE NEW PART YOU NEED TO ADD HERE:
                                if let header = option.dividerHeaderText {
                                    Text(header)
                                        .font(.caption) // Choose an appropriate font size
                                        .fontWeight(.bold) // Make it stand out as a header
                                        .foregroundColor(.gray) // Choose an appropriate color
                                        .padding(.leading, menuLeadingPadding + 5) // Indent slightly more than divider
                                        .padding(.top, 8) // Space above the header text
                                        .padding(.bottom, 4) // Space below the header text
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10) // Padding between header and scrollable menu

                Spacer() // Pushes content to top, and bottom bar to bottom if not using fixed height

                
  /*
                // Bottom Navigation Bar
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "house.fill")
                            .font(.title2)
                        Text("Home")
                            .font(.caption)
                    }
                    .foregroundColor(.blue) // Highlight selected/active icon
                    Spacer()
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                        Text("Search")
                            .font(.caption)
                    }
                    Spacer()
                    VStack {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                        Text("Favorites")
                            .font(.caption)
                    }
                    Spacer()
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.title2)
                        Text("Profile")
                            .font(.caption)
                    }
                    Spacer()
                }

                
                .padding(.vertical, 8)
                .background(Color.white.shadow(radius: 2)) // Add a subtle shadow
   */
   
            }
            // ✨ NEW: Move GIFView to the background modifier of the VStack
            .background(
                GIFView(name: "flashing2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available background space
                    .offset(x: 120, y: -170) // Maintain original offset for positioning of the GIF itself
                    .opacity(0.3)
                    .scaleEffect(0.65) // Scale down the GIF's visual size
                    .ignoresSafeArea() // Make the GIF background ignore safe areas
                    .background(Color.clear) // Ensure it doesn't have an opaque background itself if GIF has transparency
            )
            // You might still need an overall leading padding on the NavigationView or the VStack if the whole screen is too far left
            // If the entire layout (VStack + GIF background) is still off, you can add this:
            // .padding(.leading, 70) // Adjust this value to shift the whole content

            .navigationBarHidden(true) // Hide default navigation bar for custom header
            .setupListeners(
                showToastMessage: $showToastMessage,
                isToastShown: $isToastShown,
                isLoggedIn: authViewModel.authenticationState.isAuthenticated
            )
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Location Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                os_log("IslandMenu appeared", log: IslandMenulogger)
            }
            .onChange(of: authViewModel.authenticationState.isAuthenticated) { oldValue, newValue in
                if !newValue {
                    os_log("IslandMenu: Authentication state changed to false, dismissing any modals.", log: IslandMenulogger)
                }
            }
        } // End of NavigationView
    }
    // MARK: - Destination View
    @ViewBuilder // Add @ViewBuilder here
    private func destinationView(for option: IslandMenuOption) -> some View {
        switch option {
        case .profile:
            ProfileView(
                profileViewModel: profileViewModel,
                authViewModel: authViewModel,
                selectedTabIndex: .constant(LoginViewSelection.login),
                setupGlobalErrorHandler: {}
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("ProfileView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }
        
        case .addNewGym:
            AddNewIsland(
                islandViewModel: pirateIslandViewModel,
                profileViewModel: profileViewModel,
                authViewModel: authViewModel,
                islandDetails: $islandDetails // <-- CHANGE THIS BACK TO $islandDetails
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("AddNewIsland Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .updateExistingGyms:
            EditExistingIslandList()
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("EditExistingIslandList Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .allLocations:
            AllEnteredLocations()
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("AllEnteredLocations Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .currentLocation:
            ConsolidatedIslandMapView(
                viewModel: appDayOfWeekViewModel,
                enterZipCodeViewModel: enterZipCodeViewModelForAppDayOfWeek
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("ConsolidatedIslandMapView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .postalCode:
            EnterZipCodeView(
                appDayOfWeekViewModel: appDayOfWeekViewModel,
                allEnteredLocationsViewModel: allEnteredLocationsViewModel,
                enterZipCodeViewModel: enterZipCodeViewModelForAppDayOfWeek
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("EnterZipCodeView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .addOrEditScheduleOpenMat:
            DaysOfWeekFormView(
                viewModel: appDayOfWeekViewModel,
                selectedIsland: $selectedIsland,
                selectedMatTime: .constant(nil),
                showReview: .constant(false)
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("DaysOfWeekFormView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .dayOfWeek:
            DayOfWeekSearchView(
                selectedIsland: $selectedIsland,
                selectedAppDayOfWeek: .constant(nil),
                region: $region,
                searchResults: $searchResults
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("DayOfWeekSearchView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .searchReviews:
            ViewReviewSearch(
                selectedIsland: $selectedIsland,
                titleString: "Read Gym Reviews",
                enterZipCodeViewModel: enterZipCodeViewModelForReviews,
                authViewModel: authViewModel
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("ViewReviewSearch Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .submitReview:
            GymMatReviewSelect(
                selectedIsland: $selectedIsland,
                enterZipCodeViewModel: enterZipCodeViewModelForReviews,
                authViewModel: authViewModel
            )
            .onAppear {
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("GymMatReviewSelect Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }

        case .faqDisclaimer:
            FAQnDisclaimerMenuView()
            .onAppear { // Log when FAQnDisclaimerMenuView actually appears
                let userID = authViewModel.currentUserID ?? "Unknown"
                let timestamp = "\(Date())"
                os_log("FAQnDisclaimerMenuView Appeared. User: %@. Time: %@",
                        log: IslandMenulogger,
                        type: .info,
                        userID,
                        timestamp
                )
            }
        //case .recentlyViewed, .more:
            // For these new menu items, you'll need to define their actual destination views.
            // For now, they will navigate to a placeholder text view.
            //Text("Destination for \(option.rawValue)")
        case .empty:
            Text("")
        }
    }
}



struct MockPasswordHasher: PasswordHasher {
    func hashPasswordScrypt(_ password: String) throws -> HashedPassword {
        // Return a dummy hashed password for preview
        HashedPassword(hash: Data(), salt: Data(), iterations: 1)
    }

    // This is the newly required method
    func verifyPassword(_ password: String, against hashedPassword: HashedPassword) throws -> Bool {
        // For a mock, you can just return true, or false, depending on the test scenario.
        // For preview purposes, returning true is usually fine to simulate success.
        return true
    }

    func verifyPasswordScrypt(_ password: String, againstHash hashedPassword: HashedPassword) throws -> Bool {
        // Always return true for preview verification
        return true
    }
    var base64SaltSeparator: String { ":::" } // Provide a dummy separator
}

// 2. Mock Validator
struct MockValidator: Validator {
    func isValidEmail(_ email: String) -> Bool {
        return true // Always valid for preview
    }
    func isValidPassword(_ password: String) -> Bool {
        return true // Always valid for preview
    }
    func containsValidCharacters(_ text: String, allowedCharacters: CharacterSet) -> Bool {
        return true // Always valid for preview
    }
}

// Inside your PreviewAuthViewModel class

class PreviewAuthViewModel: AuthViewModel {
    @MainActor
    init(signedIn: Bool, currentUserID: String? = nil) {
        // First, create the AuthenticationState instance using the mocks
        let mockAuthenticationState = AuthenticationState(hashPassword: MockPasswordHasher(), validator: MockValidator())

        // Call the designated initializer of AuthViewModel that takes an AuthenticationState
        super.init(authenticationState: mockAuthenticationState)

        // Now, proceed to set the state on the `self.authenticationState` property.
        if signedIn {
            // Instead of directly manipulating published properties,
            // call the existing login method that does it properly.
            if let userID = currentUserID {
                // Create a dummy User object matching its required init
                let dummyUser = User(
                    email: "preview@example.com",
                    userName: "PreviewUser",
                    name: "Preview User Full Name",
                    passwordHash: Data(),          // Dummy Data
                    salt: Data(),                  // Dummy Data
                    iterations: 1,                 // Dummy Int64
                    isVerified: true,              // Assuming verified for a signed-in preview
                    belt: "Black",                 // Example optional value
                    verificationToken: nil,        // Example optional value
                    userID: userID                 // Use the provided userID
                )

                // Call the existing public login(user: User) method
                // This method correctly sets `self.currentUser` and then calls `loginCompletedSuccessfully()`
                self.authenticationState.login(user: dummyUser) // <-- FIXED LINE

            } else {
                // If signedIn is true but currentUserID is nil,
                // you might want a default dummy user or log a warning.
                // For simplicity, we can create a generic one here.
                let defaultDummyUser = User(
                    email: "default@example.com",
                    userName: "DefaultPreviewUser",
                    name: "Default Preview",
                    passwordHash: Data(),
                    salt: Data(),
                    iterations: 1,
                    isVerified: true,
                    userID: UUID().uuidString
                )
                self.authenticationState.login(user: defaultDummyUser)
            }
            // The calls to `isAuthenticated = true`, `isLoggedIn = true`,
            // and `loginCompletedSuccessfully()` are now redundant here because
            // `login(user: dummyUser)` already performs these actions internally.
            // Remove them to avoid duplicate logic or potential issues.

        } else {
            // For a non-signed-in state, simply reset
            self.authenticationState.reset()
        }
    }
}


class MockPirateIslandDataManager: PirateIslandDataManager {
    
    override init(viewContext: NSManagedObjectContext) {
        super.init(viewContext: viewContext)
    }
   
    
    override func fetchPirateIslands(sortDescriptors: [NSSortDescriptor]? = nil, predicate: NSPredicate? = nil, fetchLimit: Int? = nil) -> Result<[PirateIsland], FetchError> {
        print("MOCK: fetchPirateIslands called, returning dummy data.")

        // Initialize 'result' with a default value.
        // Since this is a mock and you intend to return success,
        // a default success value is appropriate.
        var result: Result<[PirateIsland], FetchError> = .success([]) // Initialize with an empty array on success

        viewContext.performAndWait {
            let mockIsland1 = PirateIsland(context: viewContext)
            mockIsland1.islandID = UUID()
            mockIsland1.islandName = "Mock Treasure Island"
            mockIsland1.islandLocation = "Caribbean Sea"
            mockIsland1.latitude = 34.0
            mockIsland1.longitude = -118.0
            mockIsland1.country = "Bahamas"
            mockIsland1.createdTimestamp = Date().addingTimeInterval(-86400)
            mockIsland1.lastModifiedTimestamp = Date()
            mockIsland1.createdByUserId = "mockUser1"
            mockIsland1.lastModifiedByUserId = "mockUser1"
            mockIsland1.gymWebsite = URL(string: "https://mockisland1.com")

            let mockIsland2 = PirateIsland(context: viewContext)
            mockIsland2.islandID = UUID()
            mockIsland2.islandName = "Mock Skull Island"
            mockIsland2.islandLocation = "Pacific Ocean"
            mockIsland2.latitude = 33.9
            mockIsland2.longitude = -118.1
            mockIsland2.country = "Fiji"
            mockIsland2.createdTimestamp = Date().addingTimeInterval(-172800)
            mockIsland2.lastModifiedTimestamp = Date().addingTimeInterval(-3600)
            mockIsland2.createdByUserId = "mockUser2"
            mockIsland2.lastModifiedByUserId = "mockUser2"
            mockIsland2.gymWebsite = URL(string: "https://mockisland2.com")

            result = .success([mockIsland1, mockIsland2])
        }
        return result
    }
    
    override func fetchLocalPirateIsland(withId id: String) async throws -> PirateIsland? {
            print("MOCK: fetchLocalPirateIsland called with id: \(id).")

            // The 'try' keyword is needed here because withCheckedThrowingContinuation
            // is designed for code that *can* throw, even if your mock currently doesn't.
            // It provides a way to handle errors if a real implementation or a different
            // mock scenario were to resume with a throwing error.
            return try await withCheckedThrowingContinuation { continuation in
                viewContext.performAndWait { // Use performAndWait for synchronous Core Data access
                    if id == "previewUser123" {
                        let mockIsland = PirateIsland(context: viewContext)
                        mockIsland.islandID = UUID(uuidString: id) ?? UUID()
                        mockIsland.islandName = "Preview User's Home Island"
                        mockIsland.islandLocation = "Lost At Sea"
                        mockIsland.latitude = 34.05
                        mockIsland.longitude = -118.25
                        mockIsland.country = "International Waters"
                        mockIsland.createdTimestamp = Date()
                        mockIsland.lastModifiedTimestamp = Date()
                        mockIsland.createdByUserId = "previewUser123"
                        mockIsland.lastModifiedByUserId = "previewUser123"
                        mockIsland.gymWebsite = URL(string: "https://previewhomeisland.com")
                        continuation.resume(returning: mockIsland)
                    } else {
                        continuation.resume(returning: nil)
                    }
                    // If you *did* want this mock to sometimes throw, you would
                    // explicitly call `continuation.resume(throwing: someError)` here.
                    // For example:
                    // if id == "errorID" {
                    //      continuation.resume(throwing: FetchError.itemNotFound) // Assuming FetchError has this case or you define a mock error
                    // } else if id == "previewUser123" { ... } else { ... }
                }
            }
        }
}



// MARK: - Preview
struct IslandMenu2_Previews: PreviewProvider {
    static var previews: some View {
        // Create the AuthViewModel instance directly here
        let authViewModel = PreviewAuthViewModel(signedIn: true, currentUserID: "previewUser123")
        let pirateDataManager = MockPirateIslandDataManager(viewContext: PersistenceController.preview.container.viewContext)

        // Wrap IslandMenu2 in a NavigationView or simply a Group
        // and ensure the environment objects are applied at the top level
        // so any subviews can access them.
        NavigationView { // Or just a Group if NavigationView isn't necessary
            IslandMenu2(profileViewModel: ProfileViewModel(viewContext: PersistenceController.preview.container.viewContext))
                // Apply the environment objects directly to the view that needs them, or its parent.
                // Since IslandMenu2 likely needs them, apply them here.
                .environmentObject(authViewModel)
                .environmentObject(AllEnteredLocationsViewModel(dataManager: pirateDataManager))
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
