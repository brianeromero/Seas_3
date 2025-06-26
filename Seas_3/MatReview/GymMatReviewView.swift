// GymMatReviewView.swift
//
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import FirebaseCore
import FirebaseFirestore
import os
import os.log
import FirebaseAuth


// Enum for star ratings (No changes needed here - it's already well-designed)
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

// Reusable components for review section
struct ReviewSection: View {
    @Binding var reviewText: String
    @Binding var isReviewValid: Bool
    @Binding var selectedRating: StarRating // Assuming StarRating is an Enum or similar

    let textEditorHeight: CGFloat = 150
    let cornerRadius: CGFloat = 8
    let characterLimit: Int = 300

    var body: some View {
        Section(header: Text("Write Your Review")) {
            TextEditor(text: $reviewText)
                .frame(height: textEditorHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1) // Use adaptive gray with opacity
                )
                // FIX: Updated onChange to the new iOS 17+ syntax
                .onChange(of: reviewText) { _, _ in // Using two parameters: old and new values. We don't use them, so _ is fine.
                    // Check conditions and update isReviewValid accordingly
                    if selectedRating == .zero {
                        isReviewValid = reviewText.count >= 150
                    } else {
                        isReviewValid = !reviewText.isEmpty && reviewText.count <= characterLimit
                    }
                }

            let charactersUsed = reviewText.count
            let overLimit = max(0, charactersUsed - characterLimit)
            let remainingCharacters = max(0, characterLimit - charactersUsed)

            Text("\(charactersUsed) / \(characterLimit) characters used")
                .font(.caption)
                .foregroundColor(charactersUsed > characterLimit ? .red : .secondary) // Use .secondary for adaptive gray

            if overLimit > 0 {
                Text("Over limit by \(overLimit) characters")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if remainingCharacters > 0 {
                Text("\(remainingCharacters) characters remaining")
                    .font(.caption)
                    .foregroundColor(.secondary) // Use .secondary for adaptive gray
            }

            // ✅ THIS is the special warning for zero-star rating
            if selectedRating == .zero && reviewText.count < 150 {
                Text("Your rating is zero. Please add a longer review (150+ characters).")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // This validation message needs to be carefully managed based on your isReviewValid logic.
            // It might flicker if isReviewValid changes rapidly.
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
    @Binding var reviewText: String

    var body: some View {
        Section(header: Text("Rate the Gym")) {
            HStack {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < selectedRating.rawValue ? "star.fill" : "star")
                        .foregroundColor(index < selectedRating.rawValue ? .yellow : .secondary) // Use .secondary for empty stars
                        .onTapGesture {
                            if selectedRating.rawValue == index + 1 {
                                selectedRating = .zero
                            } else {
                                selectedRating = StarRating(rawValue: index + 1) ?? .zero
                            }
                            print("Selected Rating: \(selectedRating.rawValue) star(s)")

                            // Update validation based on rating selection
                            if selectedRating == .zero {
                                isReviewValid = reviewText.count >= 150
                            } else {
                                isReviewValid = !reviewText.isEmpty && reviewText.count <= 300
                            }
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
                .foregroundColor(.primary) // Ensure text color adapts
            ForEach(StarRating.allCases, id: \.self) { rating in
                HStack {
                    ForEach(Array(rating.stars.enumerated()), id: \.0) { index, star in
                        Image(systemName: star)
                            .font(.caption)
                            .foregroundColor(star.contains(".fill") ? .yellow : .secondary) // Adapt filled/empty star colors
                            .id(rating.rawValue * 10 + index)
                    }
                    Text("\(rating.description)")
                        .font(.system(size: 10))
                        .foregroundColor(.primary) // Ensure text color adapts
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 10) // Changed padding to vertical for better spacing within the background
        .background(Color.clear) // Use Color.clear or remove background for default adaptive behavior
        // If you need a distinct background that adapts, consider Material (iOS 15+)
        // .background(.thickMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5) // Optional subtle border
        )
    }
}

// Main view for Gym Mat Review
struct GymMatReviewView: View {
    @Binding var localSelectedIsland: PirateIsland?
    @State private var isReviewsFetched = false
    @State private var showReview = false // This might be redundant if GymMatReviewView's presentation is managed by NavigationLink
    @State private var activeIsland: PirateIsland?
    @State private var reviewText: String = ""
    @State private var selectedRating: StarRating = .zero
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var cachedAverageRating: Double = 0
    // @State private var isRatingUpdated = false // REMOVED - Unused, you can safely delete this line
    @State private var cachedIsland: PirateIsland?
    // @State private var hasInitialized = false // REMOVED - Unused, you can safely delete this line

    @Environment(\.dismiss) private var dismiss // Use this instead of presentationMode

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    // @Environment(\.presentationMode) private var presentationMode // REMOVED - Deprecated, use @Environment(\.dismiss)

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    @State private var isReviewValid: Bool = false
    @State private var reviews: [Review] = []
    //var onIslandChange: (PirateIsland?) -> Void

    @State private var isReviewViewPresented = false // This also might be redundant

    init(localSelectedIsland: Binding<PirateIsland?>, callerFile: String = #file, callerFunction: String = #function) {
        self._localSelectedIsland = localSelectedIsland
        // REMOVE THIS LINE:
        // self.onIslandChange = onIslandChange // <-- DELETE THIS!
        os_log("GymMatReviewView INITIALIZED from %{public}s, function: %{public}s", log: logger, type: .info, (callerFile as NSString).lastPathComponent, callerFunction)
    }

    var body: some View {
        let _ = os_log("GymMatReviewView BODY rendered (selectedIsland: %@)", log: logger, type: .debug, localSelectedIsland?.islandName ?? "nil")

        // === THIS IS THE FULL FORM BLOCK ===
        VStack {
            Form {
                IslandSection(islands: Array(islands), selectedIsland: $localSelectedIsland, showReview: $showReview)

                ReviewSection(
                    reviewText: $reviewText,
                    isReviewValid: $isReviewValid,
                    selectedRating: $selectedRating
                )

                RatingSection(
                    selectedRating: $selectedRating,
                    isReviewValid: $isReviewValid,
                    reviewText: $reviewText
                )

                Button(action: submitReview) {
                    Text("Submit Review")
                }
                .disabled(isLoading)
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Review Submission Notice:"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }

                Section(header: Text("Average Rating")) {
                    HStack {
                        ForEach(Array(StarRating.getStars(for: cachedAverageRating).enumerated()), id: \.offset) { _, starName in
                            Image(systemName: starName)
                                .foregroundColor(.yellow)
                        }
                        Text(String(format: "%.1f", cachedAverageRating))
                            .foregroundColor(.primary)
                    }
                }
            }

            Spacer()

            StarRatingsLedger()
                .frame(height: 150)
                .padding(.horizontal, 20)
        }
        // === END FULL FORM BLOCK ===

        .navigationTitle("Add Gym Review")
        .onAppear {
            os_log("GymMatReviewView ON APPEAR for island: %@", log: logger, type: .info, localSelectedIsland?.islandName ?? "nil")
            print("🟢 GymMatReviewView ON APPEAR for island: \(localSelectedIsland?.islandName ?? "nil")")
            

        }
        .onDisappear {
            os_log("GymMatReviewView ON DISAPPEAR - localSelectedIsland: %@", log: logger, type: .info, localSelectedIsland?.islandName ?? "nil")
            print("🔴 GymMatReviewView ON DISAPPEAR - localSelectedIsland: \(localSelectedIsland?.islandName ?? "nil")")

        }
        .task(id: localSelectedIsland?.objectID) {
            print("📘 GymMatReviewView .task started. Island: \(localSelectedIsland?.islandName ?? "nil")")

            
            guard let island = localSelectedIsland else {
                os_log("GymMatReviewView .task: localSelectedIsland is nil, returning.", log: logger, type: .info)
                return
            }
            guard cachedIsland?.objectID != island.objectID else {
                os_log("GymMatReviewView .task: Island selection unchanged — skipping task for %@", log: logger, type: .info, island.islandName ?? "nil")
                return
            }

            os_log("GymMatReviewView .task: Island selection changed to: %@", log: logger, type: .info, island.islandName ?? "Unknown Gym")

            cachedIsland = island
            isReviewsFetched = false // Reset for new island
            //onIslandChange(island)

            activeIsland = island
            cachedAverageRating = Double(await ReviewUtils.fetchAverageRating(
                for: island,
                in: viewContext,
                callerFunction: #function
            ))

            os_log("GymMatReviewView .task: Average rating for island %@: %.2f", log: logger, type: .info, island.islandName ?? "Unknown", cachedAverageRating)

            os_log("GymMatReviewView .task: Island selection change completed", log: logger, type: .info)
        }
    }
    
    private func submitReview() {
        guard let island = localSelectedIsland else {
            alertMessage = "Please select a Gym."
            showAlert = true
            return
        }

        if !isReviewValid {
            alertMessage = """
            We’d love your feedback:

            - If you're giving 0 stars, please include at least 150 characters to explain why.
            - For all other ratings, please keep your review under 300 characters.
            """

            showAlert = true
            return
        }

        Task {
            if let currentUser = await authViewModel.getCurrentUser() {
                if currentUser.name.isEmpty {
                    os_log("Current user name is empty", log: logger, type: .error)
                    self.alertMessage = "Could not find your profile info. Please log in again."
                    self.showAlert = true
                    return
                }

                self.isLoading = true
                os_log("Submitting review for island: %@", log: logger, type: .info, island.islandName ?? "Unknown")
                os_log("Current user submitting review: %@", log: logger, type: .info, currentUser.name)
                os_log("Current user submitting review: %@", log: logger, type: .info, currentUser.userName)

                let reviewID = UUID()
                let newReview = Review(context: self.viewContext)
                newReview.stars = Int16(self.selectedRating.rawValue)
                newReview.review = self.reviewText
                newReview.createdTimestamp = Date()
                newReview.island = island
                newReview.reviewID = reviewID
                newReview.userName = currentUser.userName

                do {
                    try self.viewContext.save()
                    os_log("Review saved to CoreData successfully", log: logger, type: .info)

                    // ✅ Await the async call
                    self.cachedAverageRating = Double(await ReviewUtils.fetchAverageRating(for: island, in: self.viewContext, callerFunction: #function))

                    self.reviewText = ""
                    self.selectedRating = .zero
                    self.isReviewValid = false

                    let db = Firestore.firestore()
                    let timestamp = Timestamp(date: newReview.createdTimestamp)

                    do {
                        // ✅ Re-add 'await' here
                        try await db.collection("reviews").document(reviewID.uuidString).setData([
                            "stars": newReview.stars,
                            "review": newReview.review,
                            "createdTimestamp": timestamp,
                            "islandID": island.islandID?.uuidString ?? "",
                            "name": newReview.userName ?? "Anonymous",
                            "reviewID": newReview.reviewID.uuidString
                        ], merge: true)


                        os_log("Review saved to Firestore successfully", log: logger, type: .info)
                        self.alertMessage = "Thanks for your review!"
                        self.showAlert = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                self.dismiss()
                            }
                        }
                    } catch {
                        os_log("Error uploading review to Firestore: %@", log: logger, type: .error, error.localizedDescription)
                        self.alertMessage = "Failed to save review to Firestore. Please try again."
                        self.showAlert = true
                    }

                } catch {
                    os_log("Error saving review to CoreData: %@", log: logger, type: .error, error.localizedDescription)
                    self.isLoading = false
                    self.alertMessage = "Failed to save review locally. Please try again."
                    self.showAlert = true
                }

                self.isLoading = false

            } else {
                os_log("Review submission failed, no user logged in", log: logger, type: .error)
                self.alertMessage = "Please log in to submit a review."
                self.showAlert = true
            }
        }
    }
}
