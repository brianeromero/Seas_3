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
    @ObservedObject var authViewModel: AuthViewModel

    @State private var filteredReviewsCache: [Review] = []
    @State private var averageRating: Double = 0.0

    @FetchRequest(entity: PirateIsland.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)])
    private var islands: FetchedResults<PirateIsland>

    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    IslandSection(
                        islands: Array(islands),
                        selectedIsland: $selectedIsland,
                        showReview: $showReview
                    )
                    .padding(.horizontal, 16)

                    if selectedIsland != nil {
                        SortSection(selectedSortType: $selectedSortType)
                            .padding(.horizontal, 16)

                        ReviewSummaryView(
                            averageRating: averageRating,
                            reviewCount: filteredReviews.count
                        )

                        if filteredReviews.isEmpty {
                            NoReviewsView(
                                selectedIsland: $selectedIsland,
                                enterZipCodeViewModel: enterZipCodeViewModel,
                                authViewModel: authViewModel
                            )

                        } else {
                            ReviewList(
                                filteredReviews: filteredReviews,
                                selectedSortType: $selectedSortType
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Read Gym Reviews")
            .onAppear {
                os_log("Read Gym Reviews page appeared", log: logger, type: .info)
                loadReviews()
            }
            .onChange(of: selectedSortType) { _ in loadReviews() }
            .onChange(of: selectedIsland) { _ in loadReviews() }
        }
    }
    
    private struct ReviewSummaryView: View {
        let averageRating: Double
        let reviewCount: Int

        var body: some View {
            VStack(alignment: .leading) {
                Text("Reviews \(reviewCount); Average Rating: \(String(format: "%.1f", averageRating))")
                    .font(.headline)

                HStack {
                    ForEach(StarRating.getStars(for: averageRating), id: \.self) { star in
                        Image(systemName: star)
                            .foregroundColor(.yellow)
                            .font(.system(size: 20))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private struct NoReviewsView: View {
        @Binding var selectedIsland: PirateIsland?
        var enterZipCodeViewModel: EnterZipCodeViewModel
        @ObservedObject var authViewModel: AuthViewModel

        var body: some View {
            NavigationLink(destination: GymMatReviewView(
                localSelectedIsland: $selectedIsland,
                enterZipCodeViewModel: enterZipCodeViewModel,
                authViewModel: authViewModel,
                onIslandChange: { _ in }
            )) {
                Text("No reviews available. Be the first to write a review!")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .underline()
                    .padding()
            }
        }
    }



    // ✅ Computed property for filtered reviews
    var filteredReviews: [Review] {
        return filteredReviewsCache
    }

    // ✅ Extracted loading logic into a separate method
    private func loadReviews() {
        guard let island = selectedIsland else {
            filteredReviewsCache = []
            averageRating = 0.0
            return
        }

        Task {
            do {
                let request = Review.fetchRequest() as! NSFetchRequest<Review>
                request.predicate = NSPredicate(format: "island == %@", island.objectID)
                request.sortDescriptors = [
                    NSSortDescriptor(key: selectedSortType.sortKey, ascending: selectedSortType.ascending)
                ]

                let fetchedReviews = try island.managedObjectContext?.fetch(request) ?? []

                // ✅ Perform state mutation asynchronously to avoid runtime warnings
                DispatchQueue.main.async {
                    filteredReviewsCache = fetchedReviews
                    // Calculate average rating using the static method from ReviewUtils
                    averageRating = Double(ReviewUtils.fetchAverageRating(for: island, in: island.managedObjectContext!))
                }
            } catch {
                os_log("Failed to fetch reviews: %@", log: logger, type: .error, error.localizedDescription)
            }
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
/*
struct ViewReviewforIsland_Previews: PreviewProvider {
    static var previews: some View {
        IslandReviewPreview()
    }
}

struct IslandReviewPreview: View {
    @State private var selectedIsland: PirateIsland?
    @State private var showReview: Bool = false

    var body: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        // Create and save a mock island
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"
        mockIsland.islandLocation = "Mock Location"

        // Create mock reviews
        for i in 1...5 {
            let mockReview = Review(context: context)
            mockReview.review = "Review \(i): This is a sample review for the mock island."
            mockReview.stars = Int16(i)
            mockReview.createdTimestamp = Date().addingTimeInterval(TimeInterval(-i * 86400))
            mockReview.island = mockIsland
        }

        try? context.save()

        selectedIsland = mockIsland

        let mockEnterZipViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: persistenceController
        )

        let mockAuthViewModel = AuthViewModel() // Replace with actual init if needed

        return ScrollView {
            ViewReviewforIsland(
                showReview: $showReview,
                selectedIsland: $selectedIsland,
                enterZipCodeViewModel: mockEnterZipViewModel,
                authViewModel: mockAuthViewModel
            )
        }
    }
}
*/
