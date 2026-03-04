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
    
    // Animation
    @State private var animateModal = false
    
    var body: some View {
        Group {
            if selectedIsland != nil {
                
                IslandModalView(
                    customMapMarker: nil,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
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
}
