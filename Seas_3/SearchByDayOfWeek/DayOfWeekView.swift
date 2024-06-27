//
//  DayOfWeekView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

struct DayOfWeekView: View {
    @ObservedObject var viewModel = AppDayOfWeekViewModel()
    @State private var isSaved = false // Track whether the data is saved

    var body: some View {
        NavigationView {
            VStack {
                ForEach(viewModel.daysOfWeek, id: \.self) { day in
                    Toggle(LocalizedStringKey(String(day.rawValue)), isOn: viewModel.binding(for: day))
                }

                Button("Save Day of Week") {
                    viewModel.saveDayOfWeek()
                    isSaved = true // Set state to indicate data is saved
                }
                .padding()

                NavigationLink(
                    destination: SavedConfirmationView(),
                    isActive: $isSaved,
                    label: {
                        EmptyView()
                    })
            }
            .onAppear {
                viewModel.fetchCurrentDayOfWeek()
                Logger.log("View appeared", view: "DayOfWeekView")
            }
            .navigationTitle("Day of Week Settings")
        }
    }
}
