//  ViewReviewforIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 8/28/24.
//

import Foundation
import SwiftUI
import CoreData
import os

import Foundation // Needed for Hashable, Identifiable, Codable

enum AppScreen: Hashable, Identifiable, Codable {
    case review(String)
    case viewAllReviews(String)
    case selectGymForReview
    case searchReviews

    // ✅ Add these new cases to support the full IslandMenu2 menu:
    case profile
    case allLocations
    case currentLocation
    case postalCode
    case dayOfWeek
    case addNewGym
    case updateExistingGyms
    // ✅ THIS IS THE CRITICAL NEW CASE YOU MUST ADD/VERIFY
    case editExistingIsland(String) // String will be the objectID.uriRepresentation().absoluteString
    case addOrEditScheduleOpenMat
    case faqDisclaimer

    var id: String {
        switch self {
        case .review(let id): return "review-\(id)"
        case .viewAllReviews(let id): return "viewAllReviews-\(id)"
        case .selectGymForReview: return "selectGymForReview"
        case .searchReviews: return "searchReviews"
        case .profile: return "profile"
        case .allLocations: return "allLocations"
        case .currentLocation: return "currentLocation"
        case .postalCode: return "postalCode"
        case .dayOfWeek: return "dayOfWeek"
        case .addNewGym: return "addNewGym"
        case .updateExistingGyms: return "updateExistingGyms"
        // ✅ VERIFY THIS ID CASE IS PRESENT for editExistingIsland
        case .editExistingIsland(let id): return "editExistingIsland-\(id)"
        case .addOrEditScheduleOpenMat: return "addOrEditScheduleOpenMat"
        case .faqDisclaimer: return "faqDisclaimer"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case review, viewAllReviews, selectGymForReview, searchReviews
        case profile, allLocations, currentLocation, postalCode, dayOfWeek
        case addNewGym, updateExistingGyms, editExistingIsland // ✅ VERIFY THIS IS IN CODINGKEYS
        case addOrEditScheduleOpenMat, faqDisclaimer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try container.decodeIfPresent(String.self, forKey: .review) {
            self = .review(id)
        } else if let id = try container.decodeIfPresent(String.self, forKey: .viewAllReviews) {
            self = .viewAllReviews(id)
        } else if container.contains(.selectGymForReview) {
            self = .selectGymForReview
        } else if container.contains(.searchReviews) {
            self = .searchReviews
        } else if container.contains(.profile) {
            self = .profile
        } else if container.contains(.allLocations) {
            self = .allLocations
        } else if container.contains(.currentLocation) {
            self = .currentLocation
        } else if container.contains(.postalCode) {
            self = .postalCode
        } else if container.contains(.dayOfWeek) {
            self = .dayOfWeek
        } else if container.contains(.addNewGym) {
            self = .addNewGym
        } else if container.contains(.updateExistingGyms) {
            self = .updateExistingGyms
        } else if let id = try container.decodeIfPresent(String.self, forKey: .editExistingIsland) { // ✅ VERIFY DECODING FOR NEW CASE
            self = .editExistingIsland(id)
        } else if container.contains(.addOrEditScheduleOpenMat) {
            self = .addOrEditScheduleOpenMat
        } else if container.contains(.faqDisclaimer) {
            self = .faqDisclaimer
        } else {
            throw DecodingError.dataCorruptedError(forKey: .review, in: container, debugDescription: "Unknown AppScreen case")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .review(let id):
            try container.encode(id, forKey: .review)
        case .viewAllReviews(let id):
            try container.encode(id, forKey: .viewAllReviews)
        case .selectGymForReview:
            try container.encodeNil(forKey: .selectGymForReview)
        case .searchReviews:
            try container.encodeNil(forKey: .searchReviews)
        case .profile:
            try container.encodeNil(forKey: .profile)
        case .allLocations:
            try container.encodeNil(forKey: .allLocations)
        case .currentLocation:
            try container.encodeNil(forKey: .currentLocation)
        case .postalCode:
            try container.encodeNil(forKey: .postalCode)
        case .dayOfWeek:
            try container.encodeNil(forKey: .dayOfWeek)
        case .addNewGym:
            try container.encodeNil(forKey: .addNewGym)
        case .updateExistingGyms:
            try container.encodeNil(forKey: .updateExistingGyms)
        case .editExistingIsland(let id): // ✅ VERIFY ENCODING FOR NEW CASE
            try container.encode(id, forKey: .editExistingIsland)
        case .addOrEditScheduleOpenMat:
            try container.encodeNil(forKey: .addOrEditScheduleOpenMat)
        case .faqDisclaimer:
            try container.encodeNil(forKey: .faqDisclaimer)
        }
    }
}

enum SortType: String, CaseIterable, Identifiable {
    case latest = "Latest"
    case oldest = "Oldest"
    case stars = "Stars"

    var id: String { self.rawValue }

    var sortKey: String {
        switch self {
        case .latest, .oldest:
            return "createdTimestamp"
        case .stars:
            return "stars" // Using "stars" directly for the sort key, assuming this is the attribute name
        }
    }

    var ascending: Bool {
        switch self {
        case .latest:
            return false
        case .oldest:
            return true
        case .stars:
            return false
        }
    }
}



struct ViewReviewforIsland: View {
    
    @Environment(\.managedObjectContext) var viewContext
    @Binding var showReview: Bool
    @Binding var navigationPath: NavigationPath

    let selectedIsland: PirateIsland

    @State private var selectedIslandInternal: PirateIsland?
    @State private var selectedSortType: SortType = .latest
    @State private var filteredReviewsCache: [Review] = []
    @State private var averageRating: Double = 0.0

    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    )
    private var islands: FetchedResults<PirateIsland>

    init(
        showReview: Binding<Bool>,
        selectedIsland: PirateIsland,
        navigationPath: Binding<NavigationPath>
    ) {
        self._showReview = showReview
        self.selectedIsland = selectedIsland
        self._selectedIslandInternal = State(initialValue: selectedIsland)
        self._navigationPath = navigationPath

        os_log("ViewReviewforIsland INIT - selectedIslandInternal: %@", log: logger, type: .info, selectedIsland.islandName ?? "nil")
    }

    var body: some View {
        ScrollView {
            mainContent
        }
        .navigationTitle("Read Gym Reviews")
        .onAppear(perform: handleOnAppear)
        .onChange(of: selectedSortType) { _, _ in Task { await loadReviews() } }
        .onChange(of: selectedIslandInternal) { _, _ in Task { await loadReviews() } }

        // ✅ REMOVED: The .navigationDestination modifier should NOT be here.
        // It belongs on the NavigationStack in AppRootView (handled by AppRootDestinationView).
        // .navigationDestination(for: AppScreen.self) { screen in
        //     destinationView(for: screen)
        // }
    }


    private var mainContent: some View {
        VStack(alignment: .leading) {
            IslandSection(
                islands: Array(islands),
                selectedIsland: $selectedIslandInternal,
                showReview: $showReview
            )
            .padding(.horizontal, 16)

            if let island = selectedIslandInternal {
                SortSection(selectedSortType: $selectedSortType)
                    .padding(.horizontal, 16)

                ReviewSummaryView(
                    averageRating: averageRating,
                    reviewCount: filteredReviews.count
                )

                if filteredReviews.isEmpty {
                    NoReviewsView(
                        selectedIsland: $selectedIslandInternal,
                        path: $navigationPath // This correctly pushes to the shared path
                    )
                } else {
                    ReviewList(
                        filteredReviews: filteredReviews,
                        selectedSortType: $selectedSortType
                        // If ReviewList itself contains NavigationLinks that push AppScreen values,
                        // it might need the navigationPath binding as well.
                        // For now, assuming FullReviewView is pushed directly by destination:
                    )

                    AddMyOwnReviewView(
                        island: island,
                        path: $navigationPath // This correctly pushes to the shared path
                    )
                }
            } else {
                Text("Please select a gym to view reviews.")
                    .padding()
            }
        }
        .padding()
    }

    /*
    private func destinationView(for screen: AppScreen) -> some View {
        switch screen {
        case .review(let islandIDString):
            os_log("Navigating to GymMatReviewView for islandID: %@", log: logger, type: .info, islandIDString)

            guard let url = URL(string: islandIDString),
                  let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
                return AnyView(Text("Error: Invalid Island ID for review."))
            }

            do {
                let island = try viewContext.existingObject(with: objectID) as? PirateIsland
                if let island = island {
                    return AnyView(GymMatReviewView(
                        localSelectedIsland: .constant(island),
                        callerFile: #file,
                        callerFunction: #function
                    ))
                } else {
                    return AnyView(Text("Error: Island not found for review."))
                }
            } catch {
                return AnyView(Text("Error fetching island: \(error.localizedDescription)"))
            }

        case .selectGymForReview:
            return AnyView(GymMatReviewSelect(
                selectedIsland: $selectedIslandInternal,
                navigationPath: $navigationPath
            ))

        case .viewAllReviews(let islandIDString):
            os_log("Navigating to ViewReviewforIsland for islandID: %@", log: logger, type: .info, islandIDString)

            guard let url = URL(string: islandIDString),
                  let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
                return AnyView(Text("Error: Invalid Island ID for all reviews."))
            }

            do {
                let island = try viewContext.existingObject(with: objectID) as? PirateIsland
                if let island = island {
                    return AnyView(ViewReviewforIsland(
                        showReview: .constant(true),
                        selectedIsland: island,
                        navigationPath: $navigationPath
                    ))
                } else {
                    return AnyView(Text("Error: Island not found for all reviews."))
                }
            } catch {
                return AnyView(Text("Error fetching island: \(error.localizedDescription)"))
            }

        case .searchReviews:
            return AnyView(ViewReviewSearch(selectedIsland: $selectedIslandInternal, titleString: "Search Gym Reviews", navigationPath: $navigationPath))

        // --- Handle all other cases here with a default placeholder ---
        case .profile, .allLocations, .currentLocation, .postalCode, .dayOfWeek,
             .addNewGym, .updateExistingGyms, .addOrEditScheduleOpenMat, .faqDisclaimer:
            return AnyView(Text("Navigation to \(screen.id) is not handled in ViewReviewforIsland."))

        case .editExistingIsland(_):
            <#code#>
        }
    }

     */

    private func handleOnAppear() {
        os_log("ViewReviewforIsland onAppear - island: %@", log: logger, type: .info, selectedIslandInternal?.islandName ?? "nil")
        guard selectedIslandInternal != nil else { return }
        Task { await loadReviews() }
    }

    var filteredReviews: [Review] {
        filteredReviewsCache
    }

    private struct ReviewSummaryView: View {
        let averageRating: Double
        let reviewCount: Int

        var body: some View {
            VStack(alignment: .leading) {
                Text("Reviews \(reviewCount); Average Rating: \(String(format: "%.1f", averageRating))")
                    .font(.headline)

                HStack {
                    ForEach(Array(StarRating.getStars(for: averageRating).enumerated()), id: \.offset) { _, star in
                        Image(systemName: star)
                            .foregroundColor(.yellow)
                            .font(.system(size: 20))
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 16)
        }
    }

    private struct NoReviewsView: View {
        @Binding var selectedIsland: PirateIsland?
        @Binding var path: NavigationPath

        @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel // Assuming correct type
        @EnvironmentObject var authViewModel: AuthViewModel

        var body: some View {
            Button {
                if let island = selectedIsland {
                    os_log("Tapped 'No reviews available' button, appending AppScreen.review to path", log: logger, type: .info, island.islandName ?? "nil")
                    path.append(AppScreen.review(island.objectID.uriRepresentation().absoluteString))
                }
            } label: {
                Text("No reviews available. Be the first to write a review!")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .underline()
                    .padding()
            }
        }
    }

    private struct AddMyOwnReviewView: View {
        let island: PirateIsland
        @Binding var path: NavigationPath

        var body: some View {
            VStack {
                Button {
                    os_log("✅ AddMyOwnReviewView: Tapped button to navigate to review screen for island: %@", log: logger, type: .info, island.islandName ?? "nil")
                    path.append(AppScreen.review(island.objectID.uriRepresentation().absoluteString))
                } label: {
                    Text("Add My Own Review!")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .underline()
                        .padding()
                }
            }
        }
    }


    private func loadReviews() async {
        guard let island = selectedIslandInternal else {
            await MainActor.run {
                filteredReviewsCache = []
                averageRating = 0.0
            }
            os_log("ViewReviewforIsland: loadReviews called with nil island", log: logger, type: .info)
            return
        }

        os_log("ViewReviewforIsland: Loading reviews for island: %@", log: logger, type: .info, island.islandName ?? "Unknown")

        do {
            guard let context = island.managedObjectContext else {
                os_log("Error: Managed object context not found for selected island in loadReviews.", log: logger, type: .error)
                await MainActor.run {
                    filteredReviewsCache = []
                    averageRating = 0.0
                }
                return
            }

            let fetchedReviews = try await context.perform {
                let request = Review.fetchRequest() as! NSFetchRequest<Review>
                request.predicate = NSPredicate(format: "island == %@", island)
                request.sortDescriptors = [
                    NSSortDescriptor(key: selectedSortType.sortKey, ascending: selectedSortType.ascending)
                ]
                return try context.fetch(request)
            }

            let fetchedAvgRating = await ReviewUtils.fetchAverageRating(
                for: island,
                in: context,
                callerFunction: "ViewReviewforIsland.loadReviews"
            )

            await MainActor.run {
                self.filteredReviewsCache = fetchedReviews
                self.averageRating = Double(fetchedAvgRating)
            }

            os_log("ViewReviewforIsland: Updated reviews and average rating for island %@", log: logger, type: .info, island.islandName ?? "Unknown")

        } catch {
            os_log("ViewReviewforIsland: Failed to fetch reviews: %@", log: logger, type: .error, error.localizedDescription)
            await MainActor.run {
                self.filteredReviewsCache = []
                self.averageRating = 0.0
            }
        }
    }
}


// MARK: - ReviewList

struct ReviewList: View {
    var filteredReviews: [Review]
    @Binding var selectedSortType: SortType

    var body: some View {
        VStack {
            if !filteredReviews.isEmpty {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredReviews, id: \.reviewID) { review in
                        // This NavigationLink uses the older 'destination:' syntax.
                        // For full NavigationStack integration, it should push an AppScreen value.
                        // Keeping it as is for now, but note for future refactoring.
                        NavigationLink(destination: FullReviewView(review: review)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(review.review)
                                    .font(.body)
                                    .lineLimit(2)

                                HStack {
                                    ForEach(0..<Int(review.stars), id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                    }

                                    Spacer()

                                    Text(review.createdTimestamp, style: .date)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6)) // Use system color for background
                            .cornerRadius(10)
                            .shadow(radius: 3)
                        }
                        .buttonStyle(PlainButtonStyle()) // Remove default button styling
                    }
                }
                .padding() // This padding will create a margin around the LazyVStack
            } else {
                Text("No reviews available.")
            }
        }
    }
}



// MARK: - SortSection (No changes needed)

struct SortSection: View {
    @Binding var selectedSortType: SortType

    var body: some View {
        HStack {
            Text("Sort By")
                .font(.headline)

            Spacer()

            Picker("Sort By", selection: $selectedSortType) {
                ForEach(SortType.allCases, id: \.self) { sortType in
                    Text(sortType.rawValue)
                        .tag(sortType)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.bottom, 16)
    }
}


// MARK: - FullReviewView (No changes needed)

struct FullReviewView: View {
    var review: Review

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(review.review)
                    .font(.body)
                    .padding()

                HStack {
                    ForEach(0..<Int(review.stars), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }

                    Spacer()

                    Text(review.createdTimestamp, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .navigationTitle("Full Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}
