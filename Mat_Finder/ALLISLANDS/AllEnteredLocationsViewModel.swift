//
//  AllEnteredLocationsViewModel.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/29/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import CoreLocation
import MapKit


final class AllEnteredLocationsViewModel: ObservableObject {
    @Published var allIslands: [PirateIsland] = []
    @Published var errorMessage: String?
    @Published var isDataLoaded = false
    @Published var cameraPosition: MapCameraPosition = .automatic

    private let dataManager: PirateIslandDataManager
    private var hasSetInitialRegion = false

    init(dataManager: PirateIslandDataManager) {
        self.dataManager = dataManager
    }

    func fetchPirateIslands() {
        isDataLoaded = false
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let result = self.dataManager.fetchPirateIslands()
            
            DispatchQueue.main.async {
                switch result {
                case .success(let islands):
                    self.allIslands = islands
                    withAnimation {
                        self.isDataLoaded = true
                    }

                    if !self.hasSetInitialRegion {
                        self.cameraPosition = .automatic
                        self.hasSetInitialRegion = true
                    }

                case .failure(let error):
                    self.errorMessage = "Failed to load pirate islands: \(error.localizedDescription)"
                    self.isDataLoaded = true
                }
            }
        }
    }

    func setRegionToUserLocation(_ location: CLLocationCoordinate2D) {
        guard !hasSetInitialRegion else { return }
        
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        }
        hasSetInitialRegion = true
    }

}
