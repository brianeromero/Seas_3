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