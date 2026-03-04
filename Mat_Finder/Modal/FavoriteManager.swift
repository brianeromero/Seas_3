//
//  FavoriteManager.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/3/26.
//  Updated for in-memory caching
//

import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class FavoriteManager: ObservableObject {

    static let shared = FavoriteManager()

    private let db = Firestore.firestore()

    // 🔥 In-memory cache
    @Published private(set) var favoriteIslandIDs: Set<String> = []

    private init() {}

    // MARK: - Load All Favorites (Call Once After Login)
    func loadFavorites() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            favoriteIslandIDs = []
            return
        }

        do {
            let snapshot = try await db.collection("users")
                .document(userID)
                .collection("favorites")
                .getDocuments()

            let ids = snapshot.documents.map { $0.documentID }
            favoriteIslandIDs = Set(ids)

        } catch {
            print("Error loading favorites:", error)
            favoriteIslandIDs = []
        }
    }

    // MARK: - Check Favorite (Instant - No Firestore Read)
    func isFavorite(islandID: String) -> Bool {
        favoriteIslandIDs.contains(islandID)
    }

    // MARK: - Add Favorite
    func addFavorite(islandID: String) async {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let doc = db.collection("users")
            .document(userID)
            .collection("favorites")
            .document(islandID)

        do {
            try await doc.setData([
                "createdAt": FieldValue.serverTimestamp()
            ])

            // 🔥 Update cache immediately
            favoriteIslandIDs.insert(islandID)

        } catch {
            print("Error adding favorite:", error)
        }
    }

    // MARK: - Remove Favorite
    func removeFavorite(islandID: String) async {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let doc = db.collection("users")
            .document(userID)
            .collection("favorites")
            .document(islandID)

        do {
            try await doc.delete()

            // 🔥 Update cache immediately
            favoriteIslandIDs.remove(islandID)

        } catch {
            print("Error removing favorite:", error)
        }
    }

    // MARK: - Clear Cache (Call On Logout)
    func clearFavorites() {
        favoriteIslandIDs = []
    }
}
