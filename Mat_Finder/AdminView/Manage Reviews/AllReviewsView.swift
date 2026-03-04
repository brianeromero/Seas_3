//
//  AllReviewsView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/14/25.
//

import Foundation
import SwiftUI
import CoreData
import os


// MARK: - AllReviewsView
struct AllReviewsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedSortType: SortType = .latest
    @State private var allReviews: [Review] = []
    @State private var averageRating: Double = 0.0
    
    let island: PirateIsland   // 👈 ADD THIS

    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text("All Gym Reviews")
                    .font(.title)
                    .bold()
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                
                // Sort Section
                SortSection(selectedSortType: $selectedSortType)
                    .padding(.horizontal, 16)

                // Review Summary
                ReviewSummaryView(
                    averageRating: averageRating,
                    reviewCount: allReviews.count
                )
                
                // Reviews List
                if allReviews.isEmpty {
                    Text("No reviews available.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(allReviews, id: \.objectID) { review in
                        HStack(alignment: .top) {
                            ReviewRow(review: review)
                            Spacer()
                            Button(role: .destructive) {
                                deleteReview(review)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("View All Reviews")
        .onAppear(perform: loadAllReviews)
        .onChange(of: selectedSortType) { _, _ in
            loadAllReviews()
        }
    }
    
    // MARK: - Load Reviews
    private func loadAllReviews() {
        os_log("AllReviewsView: Loading reviews", log: logger, type: .info)
        
        let request = NSFetchRequest<Review>(entityName: "Review")
        
        // ✅ Filter by THIS island
        request.predicate = NSPredicate(format: "island == %@", island)
        
        request.sortDescriptors = [
            NSSortDescriptor(key: selectedSortType.sortKey, ascending: selectedSortType.ascending)
        ]
        
        do {
            let reviews = try viewContext.fetch(request)
            allReviews = reviews
            
            // ✅ Use shared average calculator
            Task {
                averageRating = await ReviewUtils.fetchAverageRating(
                    for: island,
                    in: viewContext
                )
            }
            
            os_log("Loaded %d reviews for island", log: logger, type: .info, reviews.count)
            
        } catch {
            os_log("Fetch failed: %@", log: logger, type: .error, error.localizedDescription)
            allReviews = []
            averageRating = 0.0
        }
    }
    
    // MARK: - Delete Review
    private func deleteReview(_ review: Review) {
        let reviewIDString = review.reviewID.uuidString
        
        viewContext.delete(review)
        do {
            try viewContext.save()
            allReviews.removeAll { $0.objectID == review.objectID }

            // ✅ Recalculate average immediately
            averageRating = allReviews.isEmpty ? 0.0 :
                allReviews.reduce(0.0) { $0 + Double($1.stars) } / Double(allReviews.count)
            

        } catch {
            os_log("Failed to delete review from Core Data: %@", type: .error, error.localizedDescription)
        }

        Task {
            do {
                try await FirestoreManager.shared.deleteDocument(in: .reviews, id: reviewIDString)
            } catch {
                print("Failed to delete review from Firestore: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - ReviewRow
struct ReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(review.review)
                .font(.body)
                .lineLimit(2)
            
            HStack {
                ForEach(0..<Int(review.stars), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
                Spacer()
                // Directly use createdTimestamp since it's non-optional
                Text(review.createdTimestamp, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

// MARK: - ReviewSummaryView
struct ReviewSummaryView: View {
    let averageRating: Double
    let reviewCount: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text("Reviews: \(reviewCount); Average Rating: \(String(format: "%.1f", averageRating))")
                .font(.headline)
            HStack {
                ForEach(Array(StarRating.getStars(for: averageRating).enumerated()), id: \.offset) { _, star in
                    Image(systemName: star)
                        .foregroundColor(.yellow)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
    }
}


struct AdminReviewsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var allReviews: [Review] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                if allReviews.isEmpty {
                    Text("No reviews found.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(allReviews, id: \.objectID) { review in
                        HStack(alignment: .top) {
                            AdminReviewRow(review: review)

                            Spacer()

                            Button(role: .destructive) {
                                deleteReview(review)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
        }
        .navigationTitle("All Reviews")
        .onAppear(perform: loadReviews)
    }

    private func loadReviews() {
        let request: NSFetchRequest<Review> = Review.fetchRequest() as! NSFetchRequest<Review>
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdTimestamp", ascending: false)
        ]

        do {
            allReviews = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch reviews: \(error.localizedDescription)")
        }
    }

    private func deleteReview(_ review: Review) {
        let reviewIDString = review.reviewID.uuidString

        viewContext.delete(review)

        do {
            try viewContext.save()
            allReviews.removeAll { $0.objectID == review.objectID }
        } catch {
            print("Core Data delete failed")
        }

        Task {
            try? await FirestoreManager.shared.deleteDocument(in: .reviews, id: reviewIDString)
        }
    }
}

struct AdminReviewRow: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            HStack {
                Text(review.island?.islandName ?? "Unknown Gym")
                    .font(.headline)
                
                Spacer()
                
                Text(review.createdTimestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                ForEach(0..<Int(review.stars), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            Text(review.review)
                .font(.body)
            
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
