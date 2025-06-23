//
//  IslandModalContainer.swift
//  Seas_3
//
//  Created by Brian Romero on 9/20/24.
//

import Foundation
import SwiftUI

struct IslandModalContainer: View {
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedDay: DayOfWeek?
    @Binding var showModal: Bool
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var isLoading = true
    @Binding var navigationPath: NavigationPath


    var body: some View {
        if let selectedIsland = selectedIsland {
            IslandModalView(
                customMapMarker: nil,
                islandName: selectedIsland.islandName ?? "",
                islandLocation: selectedIsland.islandLocation ?? "",
                formattedCoordinates: selectedIsland.formattedCoordinates,
                createdTimestamp: selectedIsland.createdTimestamp?.description ?? "No timestamp available", // Safely unwrapping
                formattedTimestamp: selectedIsland.formattedTimestamp,
                gymWebsite: selectedIsland.gymWebsite,
                dayOfWeekData: [],
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                selectedIsland: $selectedIsland,
                viewModel: viewModel,
                selectedDay: $selectedDay,
                showModal: $showModal,
                enterZipCodeViewModel: enterZipCodeViewModel,
                navigationPath: $navigationPath // ✅ Add this

            )
        } else {
            EmptyView()
        }
    }
}
