//
//  GymsNearMeListView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/17/26.
//

import SwiftUI
import CoreLocation   // 👈 ADD THIS

struct GymsNearMeListView: View {

    let islands: [PirateIsland]
    let userLocation: CLLocation?
    let radius: Double   // 👈 ADD THIS

    let onSelect: (PirateIsland) -> Void

    @State private var filter: DistanceFilter = .ten

    private func distance(for island: PirateIsland) -> Double? {
        guard
            let userLocation,
            island.latitude != 0,
            island.longitude != 0
        else { return nil }

        let islandLocation = CLLocation(
            latitude: island.latitude,
            longitude: island.longitude
        )

        return userLocation.distance(from: islandLocation) / 1609.34
    }

    private var filteredIslands: [PirateIsland] {
        islands.filter {
            guard let miles = distance(for: $0) else { return true }
            return miles <= min(filter.rawValue, radius)
        }
    }

    private var sortedIslands: [PirateIsland] {
        filteredIslands.sorted {
            let d1 = distance(for: $0) ?? .greatestFiniteMagnitude
            let d2 = distance(for: $1) ?? .greatestFiniteMagnitude
            return d1 < d2
        }
    }

    var body: some View {

        NavigationStack {

            VStack {

                Picker("Distance", selection: $filter) {
                    ForEach(DistanceFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {

                    ForEach(sortedIslands, id: \.objectID) { island in

                        Button {
                            onSelect(island)
                        } label: {

                            VStack(alignment: .leading, spacing: 4) {

                                IslandListItem(
                                    island: island,
                                    selectedIsland: .constant(nil)
                                )

                                if let miles = distance(for: island) {
                                    Text(String(format: "%.1f miles away", miles))
                                        .font(.caption2)
                                        .foregroundColor(.accentColor.opacity(0.6))
                                }
                            }
                        }
                    }
                }
            }

            .navigationTitle("Locations (\(sortedIslands.count))")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
