//
//  DayOfWeekView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct DayOfWeekView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel // Pass selectedIsland to the view model
    @State private var isSaved = false // Track whether the data is saved

    init(selectedIsland: PirateIsland?) {
        self.viewModel = AppDayOfWeekViewModel(selectedIsland: selectedIsland)
    }

    var body: some View {
        NavigationView {
            VStack {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Toggle(day.displayName, isOn: viewModel.binding(for: day))
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
                viewModel.fetchCurrentDayOfWeek() // Correct method invocation
                Logger.log("View appeared", view: "DayOfWeekView")
            }
            .navigationTitle("Day of Week Settings")
        }
    }
}

struct DayOfWeekView_Previews: PreviewProvider {
    static var previews: some View {
        DayOfWeekView(selectedIsland: nil) // Pass selectedIsland here for preview or testing
    }
}
