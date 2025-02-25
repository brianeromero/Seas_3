//  ViewReviewforIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 8/28/24.
//

import Foundation
import SwiftUI
import CoreData
import os

enum SortType: String, CaseIterable {
    case latest = "Latest"
    case oldest = "Oldest"
    case stars = "Stars"

    var sortKey: String {
        switch self {
        case .latest, .oldest:
            return "createdTimestamp"
        case .stars:
            return "stars"
        }
    }

    var ascending: Bool {
        switch self {
        case .latest, .stars:
            return false
        case .oldest:
            return true
        }
    }
}

struct ViewReviewforIsland: View {
    @State private var isReviewViewPresented = false

    @Binding var showReview: Bool
    @Binding var selectedIsland: PirateIsland?
    @State private var selectedSortType: SortType = .latest
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @State private var previousReviewCount = 0
    @State private var previousSortType: SortType = .latest
    @State private var filteredReviewsCache: [Review] = [] // Cache for filtered reviews
    
    @State private var hasInitializedGymMatReviewView = false
    

    // FetchRequest for Pirate Islands
    @FetchRequest(entity: PirateIsland.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)])
    private var islands: FetchedResults<PirateIsland>

    // FetchRequest for Reviews related to the selected island
    @FetchRequest private var reviews: FetchedResults<Review>
    
    

    // Initializer to setup FetchRequest for Reviews
    init(selectedIsland: Binding<PirateIsland?>, showReview: Binding<Bool>, enterZipCodeViewModel: EnterZipCodeViewModel) {
        self._selectedIsland = selectedIsland
        self._showReview = showReview
        self.enterZipCodeViewModel = enterZipCodeViewModel

        let sortDescriptor = NSSortDescriptor(key: "createdTimestamp", ascending: false)

        // Predicate that ensures reviews are fetched for the selected island
        let predicate: NSPredicate
        if let island = selectedIsland.wrappedValue {
            predicate = NSPredicate(format: "island == %@", island.objectID)
        } else {
            // Log an error or handle the case where selectedIsland is unexpectedly nil
            os_log("Error: selectedIsland is nil", log: logger, type: .error)
            predicate = NSPredicate(value: false) // Avoid fetching anything if unexpectedly nil
        }

        let fetchLimit = 10 // Limit the number of reviews fetched

        os_log("Initializing ViewReviewforIsland with selectedIsland: %@", log: logger, type: .info, selectedIsland.wrappedValue?.islandName ?? "None")

        // Typecast the fetch request to NSFetchRequest<Review>
        let request = Review.fetchRequest() as! NSFetchRequest<Review>
        request.sortDescriptors = [sortDescriptor]
        request.predicate = predicate
        request.fetchLimit = fetchLimit // Set fetch limit

        self._reviews = FetchRequest(fetchRequest: request, animation: .default)
    }


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    IslandSection(islands: Array(islands), selectedIsland: $selectedIsland, showReview: $showReview)
                        .padding(.horizontal, 16)

                    if selectedIsland != nil {
                        SortSection(selectedSortType: $selectedSortType)
                            .padding(.horizontal, 16)

                        Text("Reviews \(reviews.count)")


                        if reviews.isEmpty {
                            if !hasInitializedGymMatReviewView {
                                NavigationLink(destination: GymMatReviewView(
                                    localSelectedIsland: $selectedIsland,
                                    enterZipCodeViewModel: enterZipCodeViewModel,
                                    onIslandChange: { _ in }
                                )) {
                                    Text("No reviews available. Be the first to write a review!")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                        .underline()
                                        .padding()
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    os_log("NavigationLink tapped", log: logger, type: .info)
                                    os_log("Selected island: %@", log: logger, type: .info, selectedIsland?.islandName ?? "None")
                                    hasInitializedGymMatReviewView = true
                                })
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("View Reviews for Gym")
        }
    }



    // Commented out the filteredReviews property for now
    /*
    var filteredReviews: [Review] {
        // Log whenever the computed property is called
        os_log("filteredReviews called", log: logger, type: .info)

        if reviews.count == previousReviewCount && selectedSortType == previousSortType {
            // No change in reviews or sort type, skip filtering
            os_log("Returning cached filtered reviews", log: logger, type: .info)
            return filteredReviewsCache
        }

        os_log("Filtering %d reviews using sort type: %@", log: logger, type: .info, reviews.count, selectedSortType.rawValue)

        os_log("Reviews count before checking empty: %d", log: logger, type: .info, reviews.count)
        if reviews.isEmpty { // Check if initial fetch is empty
            os_log("Initial reviews fetch is empty, skipping further filtering.", log: logger, type: .info)
            previousReviewCount = reviews.count
            previousSortType = selectedSortType
            return []
        }

        let filteredByIsland = ReviewUtils.getReviews(from: reviews)

        let sortedReviews = filteredByIsland.sorted { review1, review2 in
            switch selectedSortType {
            case .latest:
                return review1.createdTimestamp > review2.createdTimestamp
            case .oldest:
                return review1.createdTimestamp < review2.createdTimestamp
            case .stars:
                return review1.stars > review2.stars
            }
        }

        // Log the number of reviews after sorting
        os_log("Sorted %d reviews", log: logger, type: .info, sortedReviews.count)

        // Cache the filtered reviews to avoid re-filtering if nothing has changed
        previousReviewCount = reviews.count
        previousSortType = selectedSortType
        filteredReviewsCache = sortedReviews

        return sortedReviews
    }
    */
}


// Placeholder for future filtering logic
// ReviewList(filteredReviews: Array(reviews), selectedSortType: $selectedSortType)

struct ReviewList: View {
    // var filteredReviews: [Review] // Commented out
    @Binding var selectedSortType: SortType

    var body: some View {
        VStack {
            // if !filteredReviews.isEmpty { // Commented out
            if ![].isEmpty { // Temporary placeholder to prevent errors
                List {
                    // ForEach(filteredReviews, id: \.reviewID) { review in // Commented out
                    ForEach([] as [Review], id: \.reviewID) { review in // Temporary empty array
                        NavigationLink(destination: FullReviewView(review: review)) {
                            VStack(alignment: .leading) {
                                Text(review.review.prefix(100) + (review.review.count > 100 ? "..." : ""))
                                    .font(.body)
                                    .lineLimit(2)
                                    .padding(.vertical, 4)

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
                    }
                }
                .listStyle(InsetGroupedListStyle())
            } else {
                Text("No reviews available. Be the first to write a review!")
            }
        }
    }
}


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

struct ViewReviewforIsland_Previews: PreviewProvider {
    static var previews: some View {
        IslandReviewPreview()
    }
}

struct IslandReviewPreview: View {
    @State private var selectedIsland: PirateIsland?
    @State private var showReview: Bool = false // Initialize showReview as a state variable

    var body: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        // Create and save a mock island
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"
        mockIsland.islandLocation = "Mock Location"

        // Create a variety of mock reviews for the island
        for i in 1...5 {
            let mockReview = Review(context: context)
            mockReview.review = "Review \(i): This is a sample review for the mock island."
            mockReview.stars = Int16(i) // Use sequential stars for clear testing (1 to 5)
            mockReview.createdTimestamp = Date().addingTimeInterval(TimeInterval(-i * 86400)) // Offset each review by a day
            mockReview.island = mockIsland // Correctly set the relationship
        }
        
        // Save the context
        try? context.save()

        // Set the selected island
        selectedIsland = mockIsland

        let mockViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: persistenceController
        )

        return ScrollView {
            ViewReviewforIsland(selectedIsland: $selectedIsland, showReview: $showReview, enterZipCodeViewModel: mockViewModel) // Pass showReview binding here
        }
    }
}
