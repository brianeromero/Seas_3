//
//  GymMatReviewView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData

// Define StarRating Enum with descriptions and stars array
enum StarRating: Int, CaseIterable {
    case zero = 0, one, two, three, four, five

    var description: String {
        switch self {
        case .zero: return "Trial Class Guy"
        case .one: return "5 Stripe White Belt"
        case .two: return "Under Ultra Heavy Weight Blue Belt's Half Guard"
        case .three: return "Purple Belt's Knee"
        case .four: return "Old Timey's Brown Belt's no-hand dogbar"
        case .five: return "Blackbelt's cartwheel pass to back"
        }
    }

    var stars: [String] {
        switch self {
        case .zero: return ["star", "star", "star", "star", "star"]
        case .one: return ["star.fill", "star", "star", "star", "star"]
        case .two: return ["star.fill", "star.fill", "star", "star", "star"]
        case .three: return ["star.fill", "star.fill", "star.fill", "star", "star"]
        case .four: return ["star.fill", "star.fill", "star.fill", "star.fill", "star"]
        case .five: return ["star.fill", "star.fill", "star.fill", "star.fill", "star.fill"]
        }
    }
}

struct GymMatReviewView: View {
    @State private var reviewText: String = ""
    @State private var selectedRating: StarRating = .zero
    @State private var showAlert = false
    @State private var alertMessage = ""

    @Environment(\.managedObjectContext) private var viewContext

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
                            .onChange(of: reviewText) { newValue in
                                if newValue.count > 280 {
                                    reviewText = String(newValue.prefix(280))
                                }
                            }
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
                        VStack(alignment: .leading) {  // Aligning the text to the left
                            Text("Star Ratings:")
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
            }
            .navigationTitle("Gym Mat Review")
        }
    }

    private func submitReview() {
        guard !reviewText.isEmpty else {
            alertMessage = "Review text cannot be empty."
            showAlert = true
            return
        }
        
        let newReview = Review(context: viewContext)
        newReview.stars = Int16(selectedRating.rawValue)
        newReview.review = reviewText
        
        do {
            try viewContext.save()
            alertMessage = "Thank you for your review!"
        } catch {
            alertMessage = "Failed to save review. Please try again."
        }
        
        showAlert = true
    }
}

// Preview
struct GymMatReviewView_Previews: PreviewProvider {
    static var previews: some View {
        GymMatReviewView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
