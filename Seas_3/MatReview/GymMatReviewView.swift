//  GymMatReviewView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData

enum StarRating: Int, CaseIterable {
    case zero = 0, one, two, three, four, five

    var description: String {
        switch self {
        case .zero: return "Trial Class Guy"
        case .one: return "5 Stripe White Belt"
        case .two: return "Ultra Heavy Weight Blue Belt's Half Guard"
        case .three: return "Purple Belt's Knee"
        case .four: return "Old Timey Brown Belt's Dogbar"
        case .five: return "Blackbelt's Cartwheel Pass to the Back"
        }
    }

    var stars: [String] {
        let filledStars = Array(repeating: "star.fill", count: rawValue)
        let emptyStars = Array(repeating: "star", count: 5 - rawValue)
        return filledStars + emptyStars
    }
}

struct IslandSection: View {
    @Binding var selectedIsland: PirateIsland?
    let islands: FetchedResults<PirateIsland>

    var body: some View {
        Section(header: Text("Select Gym/Island")) {
            Picker("Gym/Island", selection: $selectedIsland) {
                ForEach(islands, id: \.self) { island in
                    Text(island.islandName).tag(island as PirateIsland?)
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                if let island = newIsland {
                    print("Selected Gym/Island: \(island.islandName)")
                }
            }
        }
    }
}


struct GymMatReviewView: View {
    @State private var reviewText: String = ""
    @State private var selectedRating: StarRating = .zero
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @Binding var selectedIsland: PirateIsland?
    @Binding var isPresented: Bool

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>
    
    
    
    var averageRating: Double {
        guard let island = selectedIsland else {
            return 0
        }
        
        let reviewsFetchRequest: NSFetchRequest<Review> = Review.fetchRequest()
        reviewsFetchRequest.predicate = NSPredicate(format: "island == %@", island)
        
        do {
            let reviews = try viewContext.fetch(reviewsFetchRequest)
            let totalStars = reviews.reduce(0) { $0 + Int($1.stars) }
            return Double(totalStars) / Double(reviews.count)
        } catch {
            print("Error fetching reviews: \(error)")
            return 0
        }
    }
    

    var body: some View {
        ZStack(alignment: .bottom) {
            Form {
                IslandSection(selectedIsland: $selectedIsland, islands: islands)
                ReviewSection(reviewText: $reviewText)
                RatingSection(selectedRating: $selectedRating)
                Button(action: submitReview) {
                    Text("Submit Review")
                }
                .disabled(isLoading)
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Review Submitted"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            // Nothing here; dismissal will be handled after alert is shown
                        }
                    )
                }
                Section(header: Text("Average Rating")) {
                    HStack {
                        ForEach(0..<Int(averageRating.rounded()), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                        Text(String(format: "%.1f", averageRating))
                    }
                }
            }
            
            StarRatingsLedger()
                .frame(height: 150) // Set the height to 150
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .shadow(radius: 5)
            
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Gym Mat Review")
        .onChange(of: showAlert) { newValue in
            if !newValue && alertMessage == "Thank you for your review!" {
                isPresented = false // Dismiss the view and navigate back to IslandMenu
            }
        }
    }

    private func submitReview() {
        guard let island = selectedIsland else {
            alertMessage = "Please select a gym/island"
            showAlert = true
            return
        }
        
        isLoading = true
        
        let newReview = Review(context: viewContext)
        newReview.stars = Int16(selectedRating.rawValue)
        newReview.review = reviewText
        newReview.createdTimestamp = Date()
        newReview.island = island
        
        let reviewsFetchRequest: NSFetchRequest<Review> = Review.fetchRequest()
        reviewsFetchRequest.predicate = NSPredicate(format: "island == %@", island)
        
        do {
            let existingReviews = try viewContext.fetch(reviewsFetchRequest)
            let totalStars = existingReviews.reduce(0) { $0 + $1.stars }
            let averageStars = existingReviews.isEmpty ? newReview.stars : (totalStars + newReview.stars) / Int16(existingReviews.count + 1)
            newReview.averageStar = averageStars
        } catch {
            print("Error fetching existing reviews: \(error)")
            newReview.averageStar = newReview.stars
        }

        do {
            try viewContext.save()
            alertMessage = "Thank you for your review!"
            presentationMode.wrappedValue.dismiss() // Dismiss the view
        } catch {
            print("Error saving review: \(error)")
            alertMessage = "Failed to save review. Please try again."
        }
        
        isLoading = false
        reviewText = ""
        DispatchQueue.main.async {
            showAlert = true
        }
    }
}

struct ReviewSection: View {
    @Binding var reviewText: String

    let textEditorHeight: CGFloat = 150
    let cornerRadius: CGFloat = 8

    var body: some View {
        Section(header: Text("Write Your Review")) {
            TextEditor(text: $reviewText)
                .frame(height: textEditorHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }
}

struct RatingSection: View {
    @Binding var selectedRating: StarRating

    var body: some View {
        Section(header: Text("Rate the Gym")) {
            HStack {
                ForEach(0..<5) { index in
                    Image(systemName: index < selectedRating.rawValue ? "star.fill" : "star")
                        .foregroundColor(index < selectedRating.rawValue ? .yellow : .gray)
                        .onTapGesture {
                            if selectedRating.rawValue == index + 1 {
                                selectedRating = .zero
                            } else {
                                selectedRating = StarRating(rawValue: index + 1) ?? .zero
                            }
                            
                            print("Selected Rating: \(selectedRating.rawValue) star(s)")
                        }
                }
            }
        }
    }
}

struct StarRatingsLedger: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Star Ratings:")
                .font(.subheadline)
            ForEach(StarRating.allCases, id: \.self) { rating in
                HStack {
                    ForEach(rating.stars, id: \.self) { star in
                        Image(systemName: star)
                            .font(.caption)
                    }
                    Text("\(rating.description)")
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity) // Make the VStack as wide as its parent
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.white.opacity(0.8))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}


struct GymMatReviewView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView()
    }
}

struct PreviewView: View {
    @StateObject var viewModel = GymMatReviewViewModel()
    @State private var isGymMatReviewViewPresented = true

    var body: some View {
        let context = PersistenceController.preview.container.viewContext
        viewModel.createDummyIsland(in: context)

        return Group {
            if let island = viewModel.dummyIsland {
                GymMatReviewView(
                    selectedIsland: .constant(island),
                    isPresented: $isGymMatReviewViewPresented
                )
                .environment(\.managedObjectContext, context)
            } else {
                Text("Failed to create dummy island")
            }
        }
    }
}

class GymMatReviewViewModel: ObservableObject {
    @Published var dummyIsland: PirateIsland?

    func createDummyIsland(in context: NSManagedObjectContext) {
        let island = PirateIsland(context: context)
        island.islandName = "Sample Island"
        self.dummyIsland = island
    }
}
