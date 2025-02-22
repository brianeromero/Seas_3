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
    @Binding var localSelectedIsland: PirateIsland?
    @State private var isReviewsFetched = false
    @State private var showReview = false
    @State private var activeIsland: PirateIsland?
    @State private var reviewText: String = ""
    @State private var selectedRating: StarRating = .zero
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var cachedAverageRating: Double = 0
    @State private var isRatingUpdated = false
    @State private var cachedIsland: PirateIsland?
    
    @Binding var isPresented: Bool
    @StateObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    @State private var isReviewValid: Bool = false

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

    var body: some View {
        VStack {
            Form {
                IslandSection(islands: Array(islands), selectedIsland: $localSelectedIsland, showReview: $showReview)
                    .onChange(of: localSelectedIsland) { newIsland in
                        guard let island = newIsland else { return }
                        print("FROM GymMatReviewView: Island selection changed to \(island.islandName ?? "Unknown Gym")")
                        cachedIsland = island
                        isReviewsFetched = false      // Reset fetching state
                        onIslandChange(island)        // Notify parent view
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
                        ForEach(0..<Int(cachedAverageRating.rounded()), id: \.self) { index in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .id(index) // Ensure uniqueness
                        }
                        Text(String(format: "%.1f", cachedAverageRating))
                    }
                }
            }

            Spacer()

            StarRatingsLedger()
                .frame(height: 150)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
        }
        .onChange(of: localSelectedIsland) { newIsland in
            if let island = newIsland {
                print("GymMatReviewView selectedIsland changed to: \(island.islandName ?? "None")")
                self.activeIsland = island // Ensure it syncs correctly
            } else {
                print("GymMatReviewView selectedIsland changed to: None")
            }
        }
        .navigationTitle("Gym Mat Review")
        .onAppear {
            if let selectedIsland = localSelectedIsland {
                print("GymMatReviewView1 appeared with selectedIsland: \(selectedIsland.islandName ?? "None")")
                self.activeIsland = selectedIsland // Ensure it syncs correctly
            } else {
                print("GymMatReviewView2 appeared with selectedIsland: None")
            }

            os_log("GymMatReviewView appeared", log: logger, type: .info)
        }
    }

    private func submitReview() {
        guard let island = localSelectedIsland else {
            alertMessage = "Please Select a Gym"
            showAlert = true
            return
        }

        isLoading = true
        os_log("Submitting review for island: %@", log: logger, type: .info, island.islandName ?? "Unknown")

        let newReview = Review(context: viewContext)
        newReview.stars = Int16(selectedRating.rawValue)
        newReview.review = reviewText
        newReview.createdTimestamp = Date()
        newReview.island = island
        newReview.reviewID = UUID()

        do {
            try viewContext.save()
            os_log("Review saved to CoreData for island: %@", log: logger, type: .info, island.islandName ?? "Unknown")

            let db = Firestore.firestore()
            db.collection("reviews").document(newReview.reviewID.uuidString).setData([
                "stars": newReview.stars,
                "review": newReview.review,
                "createdTimestamp": newReview.createdTimestamp,
                "islandID": island.islandID?.uuidString ?? ""
            ]) { error in
                if let error = error {
                    os_log("Error saving review to Firestore: %@", log: logger, type: .error, error.localizedDescription)
                } else {
                    os_log("Review saved to Firestore successfully", log: logger, type: .info)
                }
            }

            isRatingUpdated = true
            cachedAverageRating = ReviewUtils.fetchAverageRating(for: island, in: viewContext)

            alertMessage = "Thank you for your review!"
            presentationMode.wrappedValue.dismiss()

        } catch {
            os_log("Error saving review to CoreData: %@", log: logger, type: .error, error.localizedDescription)
            alertMessage = "Failed to save review. Please try again."
        }

        isLoading = false
        reviewText = ""
        DispatchQueue.main.async {
            showAlert = true
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
                ForEach(0..<5, id: \.self) { index in  // Ensure unique IDs
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
                    ForEach(Array(rating.stars.enumerated()), id: \.0) { index, star in
                        Image(systemName: star)
                            .font(.caption)
                            .id(UUID()) // Ensure unique ID
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
