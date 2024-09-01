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

    var sortDescriptor: NSSortDescriptor {
        switch self {
        case .latest:
            return NSSortDescriptor(keyPath: \Review.createdTimestamp, ascending: false)
        case .oldest:
            return NSSortDescriptor(keyPath: \Review.createdTimestamp, ascending: true)
        case .stars:
            return NSSortDescriptor(keyPath: \Review.stars, ascending: false)
        }
    }
}

struct ViewReviewforIsland: View {
    @State private var selectedIsland: PirateIsland?
    @State private var selectedSortType: SortType = .latest
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    init(selectedIsland: PirateIsland? = nil) {
        self._selectedIsland = State(initialValue: selectedIsland)
    }

    var body: some View {
        VStack {
            IslandSection(selectedIsland: $selectedIsland, islands: islands)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            SortSection(selectedSortType: $selectedSortType)
                .padding(.horizontal, 16)

            ReviewList(selectedIsland: $selectedIsland, selectedSortType: $selectedSortType)
                .padding(.horizontal, 16)
        }
        .navigationBarTitle("View Reviews for Island")
        .navigationBarTitleDisplayMode(.inline)
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

    var reviews: [Review] {
        guard let island = selectedIsland else {
            return []
        }

        let reviewsFetchRequest: NSFetchRequest<Review> = Review.fetchRequest()
        reviewsFetchRequest.predicate = NSPredicate(format: "island == %@", island)
        reviewsFetchRequest.sortDescriptors = [selectedSortType.sortDescriptor]

        do {
            return try viewContext.fetch(reviewsFetchRequest)
        } catch {
            print("Error fetching reviews: \(error)")
            return []
        }
    }

    var body: some View {
        List {
            ForEach(reviews, id: \.self) { review in
                VStack(alignment: .leading) {
                    Text(review.review)
                        .font(.body)

                    HStack {
                        ForEach(Array(0..<Int(review.stars)), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }

                        Spacer()

                        Text(DateFormatter.localizedString(from: review.createdTimestamp, dateStyle: .short, timeStyle: .short))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}
struct ViewReviewforIsland_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let viewModel = GymMatReviewViewModel()
        viewModel.createDummyIsland(in: context)

        return Group {
            if let island = viewModel.dummyIsland {
                ViewReviewforIsland(selectedIsland: island)
                    .environment(\.managedObjectContext, context)
            } else {
                VStack {
                    Text("Failed to create dummy island")
                    Text("Please check the dummy data creation code")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.red)
            }
        }
    }
}
