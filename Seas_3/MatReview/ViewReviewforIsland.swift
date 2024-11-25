//
//  ViewReviewforIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 8/28/24.
//

import Foundation
import SwiftUI
import CoreData

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
    @Binding var showReview: Bool
    @Binding var selectedIsland: PirateIsland?
    @State private var selectedSortType: SortType = .latest
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    
    // FetchRequest for Pirate Islands
    @FetchRequest(entity: PirateIsland.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]) private var islands: FetchedResults<PirateIsland>
    
    // FetchRequest for Reviews related to the selected island
    @FetchRequest private var reviews: FetchedResults<Review>
    
    // The initializer here should expect the @Binding for showReview
    init(selectedIsland: Binding<PirateIsland?>, showReview: Binding<Bool>, enterZipCodeViewModel: EnterZipCodeViewModel) {
        self._selectedIsland = selectedIsland
        self._showReview = showReview  // Initialize showReview with the passed binding
        self.enterZipCodeViewModel = enterZipCodeViewModel
        
        // Define the fetch request for reviews here
        let sortDescriptor = NSSortDescriptor(key: "createdTimestamp", ascending: false)
        let predicate: NSPredicate = selectedIsland.wrappedValue == nil ?
            NSPredicate(value: false) :
            NSPredicate(format: "island == %@", selectedIsland.wrappedValue!.objectID)

        self._reviews = FetchRequest(
            entity: Review.entity(),
            sortDescriptors: [sortDescriptor],
            predicate: predicate
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    IslandSection(islands: Array(islands), selectedIsland: $selectedIsland, showReview: $showReview)
                        .padding(.horizontal, 16)

                    if selectedIsland != nil {
                        SortSection(selectedSortType: $selectedSortType)
                            .padding(.horizontal, 16)

                        Text("Reviews \(reviews.count)")

                        if !filteredReviews.isEmpty {
                            ReviewList(filteredReviews: filteredReviews, selectedSortType: $selectedSortType)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 300) // Ensure sufficient height

                            // Calculate average rating
                            let averageRatingString = ReviewUtils.averageStarRating(for: filteredReviews)
                            
                            if averageRatingString != "No reviews" {
                                if let doubleAverageRating = Double(averageRatingString) {
                                    let intAverageRating = Int(round(doubleAverageRating))

                                    HStack {
                                        Text("Average Rating: \(averageRatingString) ")
                                        ForEach(0..<5, id: \.self) { index in
                                            if index < intAverageRating {
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(.yellow)
                                            } else {
                                                Image(systemName: "star")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        Text("(\(intAverageRating))") // Display the integer average rating
                                    }
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                } else {
                                    Text("No average rating available.")
                                        .font(.headline)
                                        .padding()
                                }
                            } else {
                                Text("No reviews available. Be the first to write a review!")
                                    .font(.headline)
                                    .padding()
                            }

                        } else {
                            Text("No reviews available. Be the first to write a review!")
                                .font(.headline)
                                .padding()
                        }
                    } else {
                        Text("No Gyms Selected")
                            .foregroundColor(.gray)
                            .font(.headline)
                            .padding()
                    }
                }
            }
        }
        .navigationTitle("View Reviews for Gym")
        .onAppear {
            print("Fetched Reviews Count: \(reviews.count)")
        }
        .onChange(of: selectedSortType) { _ in
            print("Selected Sort Type: \(selectedSortType.rawValue)")
        }
    }

    var filteredReviews: [Review] {
        let filtered = ReviewUtils.getReviews(from: NSOrderedSet(array: Array(reviews)))
        return filtered.sorted { review1, review2 in
            switch selectedSortType {
            case .latest:
                return review1.createdTimestamp > review2.createdTimestamp
            case .oldest:
                return review1.createdTimestamp < review2.createdTimestamp
            case .stars:
                return review1.stars > review2.stars
            }
        }
    }
}


extension ViewReviewforIsland {
    static func getReviews(for island: PirateIsland?, allReviews: FetchedResults<Review>) -> [Review] {
        guard let island = island else { return [] }
        return allReviews.filter { $0.island == island }
    }
}

struct ReviewList: View {
    var filteredReviews: [Review]
    @Binding var selectedSortType: SortType

    var body: some View {
        VStack {
            if !filteredReviews.isEmpty {
                List {
                    ForEach(filteredReviews, id: \.reviewID) { review in
                        NavigationLink(destination: FullReviewView(review: review)) {
                            VStack(alignment: .leading) {
                                // Displaying review text with a character limit
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
