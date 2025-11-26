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

    @State private var islandDetails: IslandDetails = IslandDetails()

    // MARK: - State Variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedIsland: PirateIsland? = nil
    @ObservedObject private var locationManager = UserLocationMapViewModel.shared
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var searchResults: [PirateIsland] = []
    @StateObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    let profileViewModel: ProfileViewModel
    @Binding var navigationPath: NavigationPath

    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false

    // MARK: - Centralized ViewModel/Repository Instantiations
    private let appDayOfWeekRepository: AppDayOfWeekRepository
    private let enterZipCodeViewModelForAppDayOfWeek: EnterZipCodeViewModel
    private let enterZipCodeViewModelForReviews: EnterZipCodeViewModel
    private let pirateIslandViewModel: PirateIslandViewModel

    let menuLeadingPadding: CGFloat = 20

    // MARK: - Initialization
    init(profileViewModel: ProfileViewModel, navigationPath: Binding<NavigationPath>) {
        self.profileViewModel = profileViewModel
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

        case profile = "Profile"
        case empty = "" // Used as a placeholder for the first header
        case allLocations = "All Locations"
        case currentLocation = "Current Location"
        case postalCode = "Enter Location"
        case dayOfWeek = "Day of the Week"
        case addNewGym = "Add New Gym"
        case updateExistingGyms = "Update Existing Gyms"
        case addOrEditScheduleOpenMat = "Add or Edit Schedule/Open Mat"
        case searchReviews = "Search Reviews"
        case submitReview = "Submit a Review"
        case faqDisclaimer = "FAQ & Disclaimer"

        var iconName: String {
            switch self {
            case .profile: return "person.crop.circle"
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

    let menuItemsFlat: [IslandMenuOption] = [
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
        .faqDisclaimer,
        .profile
    ]

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
                        if option == .profile && !isLoggedIn {
                            EmptyView()
                        } else if option == .empty {
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

                        if option.needsDivider && option != .empty && !(option == .profile && !isLoggedIn) {
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

            Spacer()
        }
        .background(
            ZStack {
                GIFView(name: "flashing2")
                    .frame(width: 500, height: 450)
                    .offset(x: 100, y: -150)
                    .ignoresSafeArea()

                Color.white.opacity(0.1)
            }
        )
        .navigationBarHidden(true)
        .setupListeners(
            showToastMessage: $showToastMessage,
            isToastShown: $isToastShown,
            isLoggedIn: isLoggedIn
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Location Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Render Menu Item
    @ViewBuilder
    private func renderMenuItem(_ option: IslandMenuOption) -> some View {
        if restrictedItems.contains(option) && !isLoggedIn {
            Button {
                alertMessage = "You must be logged in to access this feature."
                showAlert = true
            } label: {
                menuItemLabel(for: option, locked: true)
            }
        } else {
            NavigationLink(value: navigationDestination(for: option)) {
                menuItemLabel(for: option, locked: false)
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
        [.dayOfWeek, .addNewGym, .updateExistingGyms, .addOrEditScheduleOpenMat]
    }

    // MARK: - Navigation Destination
    private func navigationDestination(for option: IslandMenuOption) -> AppScreen {
        switch option {
        case .profile: return .profile
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
        case .empty: return .profile
        }
    }
}
