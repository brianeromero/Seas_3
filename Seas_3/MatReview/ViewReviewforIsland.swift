//  ViewReviewforIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 8/28/24.
//

import Foundation
import SwiftUI
import CoreData
import os

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


// Define a type for your navigation destinations if they aren't already Identifiable
// This can be an enum or a struct conforming to Hashable and Identifiable
enum AppScreen: Hashable, Identifiable {
    // For navigating to the review SUBMISSION screen (GymMatReviewView) for a specific island.
    case review(PirateIsland)

    // For navigating to the screen that SHOWS ALL REVIEWS for a specific island (ViewReviewforIsland).
    case viewAllReviews(PirateIsland)

    // For navigating to the screen where the user SELECTS a gym to review (GymMatReviewSelect).
    case selectGymForReview

    // The 'id' property is crucial for Identifiable conformance, used by NavigationLink
    var id: String {
        switch self {
        case .review(let island): return "review-\(island.objectID.uriRepresentation().absoluteString)"
        case .viewAllReviews(let island): return "viewAllReviews-\(island.objectID.uriRepresentation().absoluteString)"
        case .selectGymForReview: return "selectGymForReview"
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
        let _ = os_log("ViewReviewforIsland BODY rendered", log: logger, type: .debug)

        NavigationStack(path: $navigationPath) {
            ScrollView {
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
                                path: $navigationPath
                            )
                        } else {
                            ReviewList(
                                filteredReviews: filteredReviews,
                                selectedSortType: $selectedSortType
                            )

                            AddMyOwnReviewView(
                                island: island,
                                path: $navigationPath
                            )
                        }
                    } else {
                        Text("Please select a gym to view reviews.")
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Read Gym Reviews")
            .onAppear {
                os_log("ViewReviewforIsland onAppear - island: %@", log: logger, type: .info, selectedIslandInternal?.islandName ?? "nil")

                guard selectedIslandInternal != nil else { return }
                Task { await loadReviews() }
            }
            .onChange(of: selectedSortType) { _, _ in
                Task { await loadReviews() }
            }
            .onChange(of: selectedIslandInternal) { _, _ in
                Task { await loadReviews() }
            }
            .navigationDestination(for: AppScreen.self) { screen in
                switch screen {
                case .review(let island):
                    GymMatReviewView(
                        localSelectedIsland: .constant(island),
                        callerFile: #file,
                        callerFunction: #function
                    )

                case .selectGymForReview:
                    GymMatReviewSelect(
                        selectedIsland: $selectedIslandInternal,
                        enterZipCodeViewModel: enterZipCodeViewModel,
                        authViewModel: authViewModel,
                        navigationPath: $navigationPath
                    )

                case .viewAllReviews:
                    // Prevent recursive self-navigation
                    EmptyView()
                }
            }
        }
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

        @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel
        @EnvironmentObject var authViewModel: AuthViewModel

        var body: some View {
            Button {
                if let island = selectedIsland {
                    os_log("Tapped 'No reviews available' button, appending AppScreen.review to path", log: logger, type: .info)
                    path.append(AppScreen.review(island))
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
                    path.append(AppScreen.review(island))
                } label: {
                    Text("Add My Own Review!")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .underline()
                        .padding()
                }
                .buttonStyle(.plain)
                .padding(.top)
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
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .shadow(radius: 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            } else {
                Text("No reviews available.")
            }
        }
    }
}

// MARK: - SortSection

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

// MARK: - FullReviewView

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
