// GymMatReviewView.swift
//
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import Firebase
import FirebaseFirestore
import os

// Enum for star ratings
public enum StarRating: Int, CaseIterable {
    case zero = 0, one, two, three, four, five

    public var description: String {
        switch self {
        case .zero: return "Trial Class Guy"
        case .one: return "5 Stripe White Belt"
        case .two: return "Ultra Heavy Blue Belt's Knee Shield"
        case .three: return "Purple Belt's Bolo Roll"
        case .four: return "Old Timey Brown Belt's Dogbar"
        case .five: return "Blackbelt's Cartwheel Pass to the Back"
        }
    }

    public var stars: [String] {
        let filledStars = Array(repeating: "star.fill", count: rawValue)
        let emptyStars = Array(repeating: "star", count: 5 - rawValue)
        return filledStars + emptyStars
    }
}

// Main view for Gym Mat Review
struct GymMatReviewView: View {
    @State private var showReview = false
    @State private var activeIsland: PirateIsland?
    @State private var reviewText: String = ""
    @State private var selectedRating: StarRating = .zero
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var cachedAverageRating: Double = 0 // Cached average rating
    @State private var isRatingUpdated = false // Flag to track if rating was updated
    @State private var isInitialLoad = true // Flag to track initial view load
    @Binding var localSelectedIsland: PirateIsland?
    @Binding var isPresented: Bool
    @StateObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    let onIslandChange: (PirateIsland?) -> Void

    init(
        localSelectedIsland: Binding<PirateIsland?>,
        isPresented: Binding<Bool>,
        enterZipCodeViewModel: EnterZipCodeViewModel,
        onIslandChange: @escaping (PirateIsland?) -> Void
    ) {
        self._localSelectedIsland = localSelectedIsland
        self._isPresented = isPresented
        self._enterZipCodeViewModel = StateObject(wrappedValue: enterZipCodeViewModel)
        self.onIslandChange = onIslandChange
    }

    // Modified isReviewValid to require only a non-empty review text and a selected island
    var isReviewValid: Bool {
        let isReviewTextValid = !reviewText.trimmingCharacters(in: .whitespaces).isEmpty
        return isReviewTextValid && localSelectedIsland != nil
    }

    var averageRating: Double {
        if isInitialLoad || isRatingUpdated {
            os_log("Fetching new averageRating", log: logger, type: .info)
            guard let island = localSelectedIsland else {
                os_log("No island selected", log: logger, type: .info)
                return 0
            }

            // Fetch reviews for the selected island
            let reviewsFetchRequest: NSFetchRequest<Review> = Review.fetchRequest()
            reviewsFetchRequest.predicate = NSPredicate(format: "%K == %@", "island", island)

            do {
                os_log("Fetching reviews for island: %@", log: logger, type: .info, island.islandName ?? "Unknown")
                let reviews = try viewContext.fetch(reviewsFetchRequest)

                if reviews.isEmpty {
                    os_log("No reviews found for island: %@", log: logger, type: .info, island.islandName ?? "Unknown")
                    return 0
                }

                // Use ReviewUtils to calculate average rating
                let reviewsArray = ReviewUtils.getReviews(from: island.reviews)
                let average = ReviewUtils.averageStarRating(for: reviewsArray)
                os_log("Calculated average rating for island %@: %.2f", log: logger, type: .info, island.islandName ?? "Unknown", average)

                cachedAverageRating = average
                isInitialLoad = false
                isRatingUpdated = false
                return average
            } catch {
                os_log("Error fetching reviews for island %@: %@", log: logger, type: .error, island.islandName ?? "Unknown", error.localizedDescription)
                return 0
            }
        } else {
            return cachedAverageRating
        }
    }



    private func submitReview() {
        guard let island = localSelectedIsland else {
            alertMessage = "Please Select a Gym"
            showAlert = true
            return
        }

        isLoading = true

        let newReview = Review(context: viewContext)
        newReview.stars = Int16(selectedRating.rawValue)
        newReview.review = reviewText
        newReview.createdTimestamp = Date()
        newReview.island = island
        newReview.reviewID = UUID()

        let reviewsFetchRequest: NSFetchRequest<Review> = Review.fetchRequest()
        reviewsFetchRequest.predicate = NSPredicate(format: "%K == %@", "island", island)

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

            // Save review to Firestore
            let db = Firestore.firestore()
            db.collection("reviews").document(newReview.reviewID.uuidString).setData([
                "stars": newReview.stars,
                "review": newReview.review,
                "createdTimestamp": newReview.createdTimestamp,
                "averageStar": newReview.averageStar,
                "islandID": island.islandID?.uuidString ?? ""
            ]) { error in
                if let error = error {
                    print("Error saving review to Firestore: \(error)")
                } else {
                    print("Review saved to Firestore successfully")
                }
            }

            alertMessage = "Thank you for your review!"
            presentationMode.wrappedValue.dismiss() // Dismiss the view

            // Set the flag to recalculate the rating after review submission
            isRatingUpdated = true
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

    var body: some View {
        VStack {
            Form {
                IslandSection(islands: Array(islands), selectedIsland: $activeIsland, showReview: $showReview)
                    .onChange(of: activeIsland) { newIsland in
                        if let island = newIsland {
                            localSelectedIsland = island
                        } else {
                            localSelectedIsland = nil
                        }
                        onIslandChange(newIsland)
                    }

                ReviewSection(reviewText: $reviewText, isReviewValid: isReviewValid)
                RatingSection(selectedRating: $selectedRating)
                Button(action: submitReview) {
                    Text("Submit Review")
                }
                .disabled(isLoading || !isReviewValid)
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Review Submitted"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
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

            Spacer() // Push everything to the top

            StarRatingsLedger()
                .frame(height: 150)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
        }
        .navigationTitle("Gym Mat Review")
        .onAppear {
            activeIsland = localSelectedIsland
            os_log("GymMatReviewView appeared", log: logger, type: .info)

            // Ensure data is loaded and view is rendered
            DispatchQueue.main.async {
                os_log("GymMatReviewView finished loading and rendering", log: logger, type: .info)
            }
        }
    }
}

// Reusable components for review section
struct ReviewSection: View {
    @Binding var reviewText: String
    let textEditorHeight: CGFloat = 150
    let cornerRadius: CGFloat = 8
    let characterLimit: Int = 300
    var isReviewValid: Bool

    var body: some View {
        Section(header: Text("Write Your Review")) {
            TextEditor(text: $reviewText)
                .frame(height: textEditorHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onReceive(reviewText.publisher.collect()) { newText in
                    let filteredText = String(newText.prefix(characterLimit))
                    if filteredText != reviewText {
                        reviewText = filteredText
                    }
                }

            let charactersUsed = reviewText.count
            let overLimit = max(0, charactersUsed - characterLimit)
            let remainingCharacters = max(0, characterLimit - charactersUsed)

            Text("\(charactersUsed) / \(characterLimit) characters used")
                .font(.caption)
                .foregroundColor(charactersUsed > characterLimit ? .red : .gray)

            if overLimit > 0 {
                Text("Over limit by \(overLimit) characters")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if remainingCharacters > 0 {
                Text("\(remainingCharacters) characters remaining")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(isReviewValid ? "" : "Please enter a review")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}

// Reusable components for rating section
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

// Ledger for displaying star ratings
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
                        .font(.system(size: 10))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.white.opacity(0.8))
        .cornerRadius(10)
    }
}

// Previews for GymMatReviewView
struct GymMatReviewView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView()
    }
}

struct PreviewView: View {
    @StateObject private var enterZipCodeViewModel = EnterZipCodeViewModel(
        repository: AppDayOfWeekRepository(persistenceController: PersistenceController.preview),
        persistenceController: PersistenceController.preview
    )
    @State private var selectedIsland: PirateIsland? = nil

    var body: some View {
        NavigationView {
            GymMatReviewView(
                localSelectedIsland: $selectedIsland,
                isPresented: .constant(true),
                enterZipCodeViewModel: enterZipCodeViewModel
            ) { newIsland in
                selectedIsland = newIsland
            }
            .navigationTitle("Gym Mat Review")
        }
    }
}
