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
import os.log




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
        let filledStars = Array(repeating: "star.fill", count: self.rawValue)
        let emptyStars = Array(repeating: "star", count: 5 - self.rawValue)
        return filledStars + emptyStars
    }

    // Method to generate star icons based on a given rating
    static func getStars(for rating: Double) -> [String] {
        var stars: [String] = []
        let fullStars = Int(rating)
        let partialStar = rating - Double(fullStars)

        // Add full stars
        stars.append(contentsOf: Array(repeating: "star.fill", count: fullStars))

        // Add partial star
        if partialStar >= 0.75 {
            stars.append("star.fill")  // 75% full star
        } else if partialStar >= 0.25 {
            stars.append("star.lefthalf.fill")  // 50% or 25% full star
        } else if partialStar > 0 {
            stars.append("star")  // Empty star for values < 0.25
        }

        // Add empty stars if necessary
        stars.append(contentsOf: Array(repeating: "star", count: 5 - stars.count))
        
        return stars
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
    @State private var hasInitialized = false
    
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>
    
    @State private var isReviewValid: Bool = false
    @State private var reviews: [Review] = []
    var onIslandChange: (PirateIsland?) -> Void
    
    @State private var isReviewViewPresented = false
    
    init(
        localSelectedIsland: Binding<PirateIsland?>,
        enterZipCodeViewModel: EnterZipCodeViewModel,
        onIslandChange: @escaping (PirateIsland?) -> Void
    ) {
        self._localSelectedIsland = localSelectedIsland
        self.enterZipCodeViewModel = enterZipCodeViewModel
        self.onIslandChange = onIslandChange
        os_log("GymMatReviewView initialized", log: logger, type: .info)
    }
    
    var body: some View {
        VStack {
            Form {
                IslandSection(islands: Array(islands), selectedIsland: $localSelectedIsland, showReview: $showReview)
                    .onChange(of: localSelectedIsland) { newIsland in
                        guard let island = newIsland else { return }
                        os_log("Island selection changed to: %@", log: logger, type: .info, island.islandName ?? "Unknown Gym")
                        cachedIsland = island
                        isReviewsFetched = false      // Reset fetching state
                        onIslandChange(island)        // Notify parent view
                        os_log("Island selection change completed", log: logger, type: .info)
                    }
                
                ReviewSection(reviewText: $reviewText, isReviewValid: $isReviewValid)  // Pass binding for validation
                RatingSection(selectedRating: $selectedRating, isReviewValid: $isReviewValid, reviewText: $reviewText)  // Pass reviewText binding
                
                Button(action: submitReview) {
                    Text("Submit Review")
                }
                .disabled(isLoading || !isReviewValid)  // Disable button based on validation
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
                os_log("GymMatReviewView selectedIsland changed to: %@", log: logger, type: .info, island.islandName ?? "None")
                self.activeIsland = island
                
                // Fetch average rating directly
                self.cachedAverageRating = Double(ReviewUtils.fetchAverageRating(for: island, in: viewContext, callerFunction: #function))
                os_log("Average rating for island %@: %.2f", log: logger, type: .info, island.islandName ?? "Unknown", self.cachedAverageRating)
            } else {
                os_log("GymMatReviewView selectedIsland changed to: None", log: logger, type: .info)
            }
        }
        .navigationTitle("Gym Mat Review")
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                
                os_log("GymMatReviewView body appeared", log: logger, type: .info)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    os_log("GymMatReviewView body still visible after 1 second", log: logger, type: .info)
                    os_log("GymMatReviewView initialized", log: logger, type: .info)
                }
            }
        }
    }
    
    private func submitReview() {
        guard let island = localSelectedIsland else {
            os_log("Review submission failed, no island selected", log: logger, type: .error)
            alertMessage = "Please Select a Gym"
            showAlert = true
            return
        }
        
        isLoading = true
        os_log("Submitting review for island: %@", log: logger, type: .info, island.islandName ?? "Unknown")
        
        // Create review object
        let reviewID = UUID()
        
        let newReview = Review(context: viewContext)
        newReview.stars = Int16(selectedRating.rawValue)
        newReview.review = reviewText
        newReview.createdTimestamp = Date()
        newReview.island = island
        newReview.reviewID = reviewID
        
        os_log("Saving review to CoreData", log: logger, type: .info)
        
        do {
            try viewContext.save()
            os_log("Review saved to CoreData successfully", log: logger, type: .info)
        } catch {
            os_log("Error saving review to CoreData: %@", log: logger, type: .error, error.localizedDescription)
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.alertMessage = "Failed to save review locally. Please try again."
                self.showAlert = true
            }
            return
        }
        
        // Save review to Firestore after successful Core Data save
        let db = Firestore.firestore()
        db.collection("reviews").document(reviewID.uuidString).setData([
            "stars": newReview.stars,
            "review": newReview.review,
            "createdTimestamp": newReview.createdTimestamp,
            "islandID": island.islandID?.uuidString ?? ""
        ], merge: true) { error in
            if let error = error {
                print("Error saving review to Firestore: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "Failed to save review to Firestore. Please try again."
                    self.showAlert = true
                }
            } else {
                print("Review saved to Firestore successfully")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "Thank you for your review!"
                    self.showAlert = true
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}


// Reusable components for review section
struct ReviewSection: View {
    @Binding var reviewText: String
    @Binding var isReviewValid: Bool  // Bind to the parent state
    let textEditorHeight: CGFloat = 150
    let cornerRadius: CGFloat = 8
    let characterLimit: Int = 300

    var body: some View {
        Section(header: Text("Write Your Review")) {
            TextEditor(text: $reviewText)
                .frame(height: textEditorHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onChange(of: reviewText) { _ in
                    // Update validation based on review text
                    isReviewValid = !reviewText.isEmpty && reviewText.count <= characterLimit
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
    @Binding var isReviewValid: Bool
    @Binding var reviewText: String  // Add this line to bind the review text

    var body: some View {
        Section(header: Text("Rate the Gym")) {
            HStack {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < selectedRating.rawValue ? "star.fill" : "star")
                        .foregroundColor(index < selectedRating.rawValue ? .yellow : .gray)
                        .onTapGesture {
                            if selectedRating.rawValue == index + 1 {
                                selectedRating = .zero
                            } else {
                                selectedRating = StarRating(rawValue: index + 1) ?? .zero
                            }
                            print("Selected Rating: \(selectedRating.rawValue) star(s)")

                            // Update validation based on rating selection
                            isReviewValid = selectedRating != .zero && !reviewText.isEmpty
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
                enterZipCodeViewModel: enterZipCodeViewModel
            ) { newIsland in
                selectedIsland = newIsland
            }
            .navigationTitle("Gym Mat Review")
        }
    }
}
