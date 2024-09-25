//
//  ViewReviewforIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 8/28/24.
//

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
    @State private var selectedIsland: PirateIsland?
    @State private var selectedSortType: SortType = .latest // Declare selectedSortType
    @StateObject var enterZipCodeViewModel: EnterZipCodeViewModel // Make this a parameter

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    // Initializer that accepts EnterZipCodeViewModel
    init(enterZipCodeViewModel: EnterZipCodeViewModel) {
        self._enterZipCodeViewModel = StateObject(wrappedValue: enterZipCodeViewModel)
    }

    var body: some View {
        NavigationView {
            Form {
                IslandSection(islands: Array(islands), selectedIsland: $selectedIsland)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                if selectedIsland != nil {
                    SortSection(selectedSortType: $selectedSortType)
                        .padding(.horizontal, 16)
                }

                if selectedIsland != nil {
                    ReviewList(
                        selectedIsland: $selectedIsland,
                        selectedSortType: $selectedSortType,
                        enterZipCodeViewModel: enterZipCodeViewModel
                    )
                    .padding(.horizontal, 16)
                } else {
                    Text("Please select an island to view reviews.")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .padding()
                }
            }
            .navigationTitle("View Reviews for Island")
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

struct ReviewList: View {
    @Binding var selectedIsland: PirateIsland?
    @Binding var selectedSortType: SortType
    @Environment(\.managedObjectContext) private var viewContext

    // FetchRequest for reviews, initialized without a predicate
    @FetchRequest var reviews: FetchedResults<Review>

    var enterZipCodeViewModel: EnterZipCodeViewModel

    init(selectedIsland: Binding<PirateIsland?>, selectedSortType: Binding<SortType>, enterZipCodeViewModel: EnterZipCodeViewModel) {
        self._selectedIsland = selectedIsland
        self._selectedSortType = selectedSortType
        self.enterZipCodeViewModel = enterZipCodeViewModel

        let fetchRequest: NSFetchRequest<Review> = Review.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: selectedSortType.wrappedValue.sortKey, ascending: selectedSortType.wrappedValue.ascending)]

        // Set initial predicate only if selectedIsland is not nil
        if let selectedIsland = selectedIsland.wrappedValue {
            fetchRequest.predicate = NSPredicate(format: "island == %@", selectedIsland)
        }

        self._reviews = FetchRequest<Review>(fetchRequest: fetchRequest, animation: .default)
    }

    var body: some View {
        VStack {
            if reviews.isEmpty {
                Text("No reviews available. Be the first to write a review!")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()

                NavigationLink(destination: GymMatReviewView(
                    selectedIsland: $selectedIsland,
                    isPresented: .constant(true),
                    enterZipCodeViewModel: enterZipCodeViewModel // Pass the enterZipCodeViewModel here
                )) {
                    Text("Write a Review")
                        .font(.body)
                        .foregroundColor(.blue)
                        .padding()
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                List {
                    ForEach(reviews, id: \.self) { review in
                        VStack(alignment: .leading) {
                            if review.review.count > 70 {
                                Text(review.review.prefix(70) + "...")
                                    .font(.body)

                                NavigationLink(destination: FullReviewView(review: review)) {
                                    Text("Read more")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            } else {
                                Text(review.review)
                                    .font(.body)
                            }

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
                .listStyle(InsetGroupedListStyle())
            }
        }
        .onChange(of: selectedIsland) { newIsland in
            // Update the fetch request predicate when selectedIsland changes
            if let newIsland = newIsland {
                reviews.nsPredicate = NSPredicate(format: "island == %@", newIsland)
            } else {
                reviews.nsPredicate = nil
            }
        }
        .onChange(of: selectedSortType) { newSortType in
            // Update sort descriptor when sort type changes
            let newSortDescriptor = NSSortDescriptor(key: newSortType.sortKey, ascending: newSortType.ascending)
            reviews.nsSortDescriptors = [newSortDescriptor]
        }
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
        let context = PersistenceController.preview.container.viewContext

        // Create a mock island
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"

        let mockViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            context: context
        )

        return ViewReviewforIsland(enterZipCodeViewModel: mockViewModel)
            .environment(\.managedObjectContext, context)
            .previewDisplayName("View Reviews for Island")
    }
}
