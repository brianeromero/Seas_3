//
//  IslandMenu2.swift
//  Mat_Finder
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
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @EnvironmentObject var authenticationState: AuthenticationState
    @EnvironmentObject var profileViewModel: ProfileViewModel


    @State private var islandDetails: IslandDetails = IslandDetails()

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @ObservedObject private var locationManager = UserLocationMapViewModel.shared
    @ObservedObject private var favoriteManager = FavoriteManager.shared
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var searchResults: [PirateIsland] = []
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @Binding var navigationPath: NavigationPath

    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false
    
    @State private var alertTitle = "Login Required"
    @State private var showLoginAction = false

    // MARK: - Centralized ViewModel/Repository Instantiations
    private let appDayOfWeekRepository: AppDayOfWeekRepository
    private let enterZipCodeViewModelForAppDayOfWeek: EnterZipCodeViewModel
    private let enterZipCodeViewModelForReviews: EnterZipCodeViewModel
    private let pirateIslandViewModel: PirateIslandViewModel
    
    let menuLeadingPadding: CGFloat = 20

    // MARK: - Initialization
    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath

        let sharedPersistenceController = PersistenceController.shared
        let appDayOfWeekRepository = AppDayOfWeekRepository(persistenceController: sharedPersistenceController)

        let enterZipCodeViewModelForAppDayOfWeek = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )

        let enterZipCodeViewModelForReviews = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )

        let pirateIslandViewModel = PirateIslandViewModel(persistenceController: sharedPersistenceController)

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: appDayOfWeekRepository,
            enterZipCodeViewModel: enterZipCodeViewModelForAppDayOfWeek
        ))

        self.appDayOfWeekRepository = appDayOfWeekRepository
        self.enterZipCodeViewModelForAppDayOfWeek = enterZipCodeViewModelForAppDayOfWeek
        self.enterZipCodeViewModelForReviews = enterZipCodeViewModelForReviews
        self.pirateIslandViewModel = pirateIslandViewModel
    }


    // MARK: - Enum for Menu Options
    enum IslandMenuOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }

        case empty = "" // Used as a placeholder for the first header
        case allLocations = "All Locations"
        case currentLocation = "Current Location"
        case postalCode = "Enter Location"
        case dayOfWeek = "Day of the Week"
        case addNewGym = "Add New Gym"
        case updateExistingGyms = "Update Existing Gyms"
        case addOrEditScheduleOpenMat = "Add or Edit Schedule/Open Mat"
        case searchReviews = "Read Reviews"
        case submitReview = "Submit a Review"
        case faqDisclaimer = "FAQ & Disclaimer"

        var iconName: String {
            switch self {
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

        var needsDivider: Bool {
            switch self {
            case .empty, .dayOfWeek, .addOrEditScheduleOpenMat, .submitReview:
                return true
            default:
                return false
            }
        }

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


    // With this computed property:
    private var menuItemsFlat: [IslandMenuOption] {
        [
            .empty,
            .allLocations,
            .currentLocation,
            .postalCode,
            .dayOfWeek,
            .addNewGym,
            .updateExistingGyms,
            .addOrEditScheduleOpenMat,
            .searchReviews,
            .submitReview,
            .faqDisclaimer
        ]
    }


    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Text("Mat_Finder")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    ForEach(menuItemsFlat) { option in

                        if option == .empty {

                            if let header = option.dividerHeaderText {
                                Text(header)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, menuLeadingPadding)
                                    .padding(.top, 8)
                            }

                        } else {

                            renderMenuItem(option)

                        }

                        if option.needsDivider && option != .empty {

                            Divider()
                                .padding(.leading, menuLeadingPadding)

                            if let header = option.dividerHeaderText {

                                Text(header)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, menuLeadingPadding)
                                    .padding(.top, 8)

                            }
                        }
                    }
                }
            }
            .padding(.top, 10)

            //BannerView()
               // .frame(height: 50) // adjust the height as needed
               // .frame(maxWidth: .infinity, alignment: .center)

            footerToolbar
                .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
        }
        .background(
            GeometryReader { geo in

                SwiftUIGIFView(name: "flashing16")
                    .frame(width: 140, height: 440)
                    .position(
                        x: geo.size.width * 0.75,   // left 25%
                        y: geo.size.height * 0.25   // up 10%
                    )
            }
        )
        .navigationBarHidden(true)
        .setupListeners(
            showToastMessage: $showToastMessage,
            isToastShown: $isToastShown,
            isLoggedIn: isLoggedIn
        )
        .alert(isPresented: $showAlert) {

            if showLoginAction {

                return Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    primaryButton: .default(Text("Login/Create An Account")) {
                        navigationPath.append(AppScreen.login)
                    },
                    secondaryButton: .cancel()
                )

            } else {

                return Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )

            }
        }
    }

    @ViewBuilder
    private func renderMenuItem(_ option: IslandMenuOption) -> some View {

        if restrictedItems.contains(option) && !isLoggedIn {

            Button {
                switch option {
                case .submitReview:
                    showLoginRequiredAlert(message: "You must be logged in to submit a review.")

                default:
                    showLoginRequiredAlert(message: "You must be logged in to access this feature.")
                }
            } label: {
                menuItemLabel(for: option, locked: true)
            }

        } else {

            NavigationLink(value: navigationDestination(for: option)) {
                menuItemLabel(for: option)
            }

        }
    }


    // MARK: - Menu Item Label
    private func menuItemLabel(for option: IslandMenuOption, locked: Bool = false) -> some View {
        HStack {
            if !option.iconName.isEmpty {
                Image(systemName: option.iconName)
                    .font(.system(size: 20))  // Use a consistent size
                    .frame(width: 25)
                    .foregroundColor(locked ? .secondary : .accentColor) // Use accentColor instead of white
            }

            Text(option.rawValue)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(locked ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.leading, menuLeadingPadding)
    }

    // MARK: - Computed Properties
    private var isLoggedIn: Bool {
        authViewModel.authenticationState.isAuthenticated
    }

    private var restrictedItems: [IslandMenuOption] {
        [.dayOfWeek, .addNewGym, .updateExistingGyms, .addOrEditScheduleOpenMat, .submitReview]
    }

    // MARK: - Navigation Destination
    private func navigationDestination(for option: IslandMenuOption) -> AppScreen {
        switch option {
        case .allLocations: return .allLocations
        case .currentLocation: return .currentLocation
        case .postalCode: return .postalCode
        case .dayOfWeek: return .dayOfWeek
        case .addNewGym: return .addNewGym
        case .updateExistingGyms: return .updateExistingGyms
        case .addOrEditScheduleOpenMat: return .addOrEditScheduleOpenMat
        case .searchReviews: return .searchReviews
        case .submitReview: return .selectGymForReview
        case .faqDisclaimer: return .faqDisclaimer
        case .empty: return .allLocations
        }
    }
    

    private var footerToolbar: some View {

        GeometryReader { geo in

            HStack(spacing: min(geo.size.width * 0.15, 120)) {

                Button {

                    if !isLoggedIn {

                        showLoginRequiredAlert(message: "You must be logged in to access this feature.")
                        return
                    }

                    if favoriteManager.favoriteIslandIDs.isEmpty {

                        showInfoAlert(
                            title: "No Favorites Yet",
                            message: "You haven't added any favorites yet."
                        )
                        return
                    }

                    navigationPath.append(AppScreen.favoritesMap)

                } label: {

                    VStack(spacing: 4) {

                        ZStack(alignment: .topTrailing) {

                            Image(systemName: "heart.fill")
                                .font(.system(size: 20))

                            BadgeView(count: favoriteManager.favoriteIslandIDs.count)
                                .offset(x: 10, y: -8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: favoriteManager.favoriteIslandIDs.count)
                        }

                        Text("Favorites")
                            .font(.caption)
                    }
                }


                if isLoggedIn {

                    Button {
                        navigationPath.append(AppScreen.profile)
                    } label: {

                        VStack(spacing: 4) {

                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 20))

                            Text("Profile")
                                .font(.caption)
                        }
                    }

                } else {

                    Button {
                        navigationPath.append(AppScreen.login)
                    } label: {

                        VStack(spacing: 4) {

                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 20))

                            Text("Login")
                                .font(.caption)
                        }
                    }
                }

            }
            .frame(width: min(geo.size.width * 0.9, 600))
            .padding(.vertical, 12)
            .padding(.horizontal, 28)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        }
        .frame(height: 70)
    }
    
    // MARK: - Alert Helpers
    private func showLoginRequiredAlert(message: String) {
        alertTitle = "Login Required"
        alertMessage = message
        showLoginAction = true
        showAlert = true
    }

    private func showInfoAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showLoginAction = false
        showAlert = true
    }
    
}


struct BadgeView: View {

    let count: Int

    private var displayText: String {
        count > 99 ? "99+" : "\(count)"
    }

    var body: some View {

        if count > 0 {

            Text(displayText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.red)
                .clipShape(Capsule())
        }
    }
}
