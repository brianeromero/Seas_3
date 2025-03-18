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
    @State private var filteredReviewsCache: [Review] = []
    @State private var reviews: [Review] = []
    
    @State private var averageStar: Double = 0.0  // ⭐ Store average rating

    @FetchRequest(entity: PirateIsland.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)])
    private var islands: FetchedResults<PirateIsland>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    IslandSection(islands: Array(islands), selectedIsland: $selectedIsland, showReview: $showReview)
                        .padding(.horizontal, 16)

                    if let island = selectedIsland {
                        SortSection(selectedSortType: $selectedSortType)
                            .padding(.horizontal, 16)

                        Text("Reviews \(filteredReviews.count); Average Rating: \(String(format: "%.1f", averageStar)) ⭐")

                        if filteredReviews.isEmpty {
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
                        } else {
                            ReviewList(filteredReviews: filteredReviews, selectedSortType: $selectedSortType)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("View Reviews for Gym")
            .onAppear {
                os_log("ViewReviewforIsland appeared", log: logger, type: .info)
            }
        }
    }

    var filteredReviews: [Review] {
        guard let island = selectedIsland else { return [] }

        let request = Review.fetchRequest() as! NSFetchRequest<Review>
        request.predicate = NSPredicate(format: "island == %@", island.objectID)
        request.sortDescriptors = [
            NSSortDescriptor(key: selectedSortType.sortKey, ascending: selectedSortType.ascending)
        ]

        do {
            let fetchedReviews = try island.managedObjectContext?.fetch(request) ?? []

            // Cache logic to avoid unnecessary filtering
            if fetchedReviews.count == previousReviewCount && selectedSortType == previousSortType {
                return filteredReviewsCache
            }

            previousReviewCount = fetchedReviews.count
            previousSortType = selectedSortType
            filteredReviewsCache = fetchedReviews

            // ⭐ Calculate the average star rating
            averageStar = fetchedReviews.isEmpty
                ? 0.0
                : Double(fetchedReviews.reduce(0) { $0 + Int($1.stars) }) / Double(fetchedReviews.count)

            return fetchedReviews
        } catch {
            os_log("Failed to fetch reviews: %@", log: logger, type: .error, error.localizedDescription)
            return []
        }
    }
}



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
                                Text(review.review.prefix(100) + (review.review.count > 100 ? "..." : ""))
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
            ViewReviewforIsland(showReview: $showReview, selectedIsland: $selectedIsland, enterZipCodeViewModel: mockViewModel) // Pass showReview binding here
        }
    }
}
