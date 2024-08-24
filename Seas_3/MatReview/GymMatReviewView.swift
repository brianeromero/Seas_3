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
        case .four: return "Old Timey's Brown Belt's Dogbar"
        case .five: return "Blackbelt's Cartwheel Pass to the Back"
        }
    }

    var stars: [String] {
        let filledStars = Array(repeating: "star.fill", count: self.rawValue)
        let emptyStars = Array(repeating: "star", count: 5 - self.rawValue)
        return filledStars + emptyStars
    }
}

struct GymMatReviewView: View {
    @State private var reviewText: String = ""
    @State private var selectedRating: StarRating = .zero
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    @Environment(\.managedObjectContext) private var viewContext
    var selectedIsland: PirateIsland // Ensure this property is non-optional

    // Use a NSFetchedResultsController to manage the fetch results and avoid duplicate fetches
    lazy var reviewsController: NSFetchedResultsController<Review> = {
        let fetchRequest: NSFetchRequest<Review> = Review.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "island == %@", selectedIsland)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Review.stars, ascending: false)]
        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: viewContext, sectionNameKeyPath: nil, cacheName: nil)
    }()

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Write Your Review")) {
                        TextEditor(text: $reviewText)
                            .frame(height: 150)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }

                    Section(header: Text("Rate the Gym")) {
                        HStack {
                            ForEach(0..<5) { index in
                                Image(systemName: index < selectedRating.rawValue ? "star.fill" : "star")
                                    .foregroundColor(index < selectedRating.rawValue ? .yellow : .gray)
                                    .onTapGesture {
                                        if selectedRating.rawValue == index + 1 {
                                            selectedRating = .zero // Reset to 0 stars if the same star is tapped
                                        } else {
                                            selectedRating = StarRating(rawValue: index + 1) ?? .zero
                                        }
                                        
                                        // Log the number of stars selected
                                        print("Selected Rating: \(selectedRating.rawValue) star(s)")
                                    }
                            }
                        }
                    }

                    Button(action: submitReview) {
                        Text("Submit Review")
                    }
                    .disabled(isLoading)
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("Review Submitted"),
                            message: Text(alertMessage),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }

                // Star ratings ledger aligned to the left with 0.05 margin
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Star Ratings: like a...")
                                .font(.headline)
                                .padding(.bottom, 5)
                            ForEach(StarRating.allCases, id: \.self) { rating in
                                HStack {
                                    ForEach(rating.stars, id: \.self) { star in
                                        Image(systemName: star)
                                    }
                                    Text("= \"\(rating.description)\"")
                                }
                                .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.leading, UIScreen.main.bounds.width * 0.05)  // Left margin of 0.05
                        Spacer()
                    }
                }
                
                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("Gym Mat Review")
        }
    }

    private func submitReview() {
        guard !reviewText.isEmpty else {
            alertMessage = "Please enter a review"
            showAlert = true
            return
        }
        
        isLoading = true
        
        // Create a new review and add it to the selected island's reviews
        let newReview = Review(context: viewContext)
        newReview.stars = Int16(selectedRating.rawValue)
        newReview.review = reviewText
        newReview.createdTimestamp = Date() // Set the created timestamp to the current date and time
        newReview.island = selectedIsland

        // Calculate and set the average star rating (if applicable)
        // This might involve fetching the existing reviews and calculating the average
        let reviewsFetchRequest: NSFetchRequest<Review> = Review.fetchRequest()
        reviewsFetchRequest.predicate = NSPredicate(format: "island == %@", selectedIsland)
        
        do {
            let existingReviews = try viewContext.fetch(reviewsFetchRequest)
            let totalStars = existingReviews.reduce(0) { $0 + $1.stars }
            let averageStars = existingReviews.isEmpty ? newReview.stars : (totalStars + newReview.stars) / Int16(existingReviews.count + 1)
            newReview.averageStar = averageStars
        } catch {
            print("Error fetching existing reviews: \(error)")
            newReview.averageStar = newReview.stars // Fall back to the current review's stars if there's an error
        }

        // Save the context
        do {
            try viewContext.save()
            alertMessage = "Thank you for your review!"
        } catch let error as NSError {
            print("Error saving review: \(error.userInfo)")
            alertMessage = "Failed to save review. Please try again."
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

// Preview
struct GymMatReviewView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let dummyIsland = PirateIsland(context: context)
        // Configure dummyIsland with any necessary default values

        return GymMatReviewView(selectedIsland: dummyIsland)
            .environment(\.managedObjectContext, context)
    }
}
