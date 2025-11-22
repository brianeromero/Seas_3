//
//  IslandModalContainer.swift
//  Mat_Finder
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
    @Binding var navigationPath: NavigationPath

    // NEW — smooth fade/scale for the modal
    @State private var animateModal: Bool = false

    var body: some View {
        if let selectedIsland = selectedIsland {
            IslandModalView(
                customMapMarker: nil,
                islandName: selectedIsland.islandName ?? "",
                islandLocation: selectedIsland.islandLocation ?? "",
                formattedCoordinates: selectedIsland.formattedCoordinates,
                createdTimestamp: selectedIsland.createdTimestamp?.description ?? "No timestamp available",
                formattedTimestamp: selectedIsland.formattedTimestamp,
                gymWebsite: selectedIsland.gymWebsite,
                dayOfWeekData: [],
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                selectedIsland: $selectedIsland,
                viewModel: viewModel,
                selectedDay: $selectedDay,
                showModal: $showModal,
                enterZipCodeViewModel: enterZipCodeViewModel,
                navigationPath: $navigationPath
            )
            .opacity(animateModal ? 1 : 0)
            .scaleEffect(animateModal ? 1 : 0.92)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.25)) {
                    animateModal = true
                }
            }
            .onDisappear {
                animateModal = false
            }
        } else {
            EmptyView()
        }
    }
}
