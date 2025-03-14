//
//  MatTimesViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 12/5/24.
//

import Foundation
import FirebaseFirestore

class MatTimesViewModel: ObservableObject {
    let db = Firestore.firestore()
    
    func saveMatTimesToFirestore(matTimes: [MatTime], selectedIsland: PirateIsland) async throws {
        for matTime in matTimes {
            let data: [String: Any] = [
                "time": matTime.time ?? "",
                "type": matTime.type ?? "",
                "gi": matTime.gi,
                "noGi": matTime.noGi,
                "openMat": matTime.openMat,
                "restrictions": matTime.restrictions,
                "restrictionDescription": matTime.restrictionDescription ?? "",
                "goodForBeginners": matTime.goodForBeginners,
                "kids": matTime.kids,
                "pIsland": selectedIsland.islandID ?? "",
                "createdByUserId": "Unknown User",
                "createdTimestamp": Date(),
                "lastModifiedByUserId": "Unknown User",
                "lastModifiedTimestamp": Date()
            ]
            
            try await db.collection("matTimes").document(matTime.objectID.uriRepresentation().absoluteString).setData(data)
            print("MatTime saved successfully to Firestore")
        }
    }
    
    func saveMatTimeToFirestore(matTime: MatTime, selectedAppDayOfWeek: AppDayOfWeek, selectedIsland: PirateIsland) async throws {
        let data: [String: Any] = [
            "time": matTime.time ?? "",
            "type": matTime.type ?? "",
            "gi": matTime.gi,
            "noGi": matTime.noGi,
            "openMat": matTime.openMat,
            "restrictions": matTime.restrictions,
            "restrictionDescription": matTime.restrictionDescription ?? "",
            "goodForBeginners": matTime.goodForBeginners,
            "kids": matTime.kids,
            "appDayOfWeekID": selectedAppDayOfWeek.appDayOfWeekID ?? "",
            "pIsland": selectedIsland.islandID?.uuidString ?? "",
            "createdByUserId": "Unknown User",
            "createdTimestamp": Date(),
            "lastModifiedByUserId": "Unknown User",
            "lastModifiedTimestamp": Date()
        ]
        
        // Generate a valid Firestore document ID using UUID or custom identifier
        let documentID = UUID().uuidString  // Use UUID for a valid document ID
        
        do {
            try await db.collection("matTimes").document(documentID).setData(data)
            print("MatTime saved successfully to Firestore with document ID: \(documentID)")
        } catch {
            print("Error saving mat time to Firestore: \(error.localizedDescription)")
            throw error
        }
    }

}
