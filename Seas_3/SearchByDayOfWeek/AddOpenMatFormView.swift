//
//  AddOpenMatFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//
//


import Foundation
import SwiftUI


struct AddOpenMatFormView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedIsland: PirateIsland?

    private var isSaveEnabled: Bool {
        viewModel.selectedDays.count > 0
    }

    var body: some View {
        NavigationView {
            Form {
                daysOfWeekSection
            }
            .navigationBarTitle("Add Open Mat Times / Class Schedule", displayMode: .inline)
        }
    }

    private var daysOfWeekSection: some View {
        Section(header: Text("Days")) {
            ForEach(DayOfWeek.allCases, id: \.self) { day in
                VStack(alignment: .leading) {
                    Text(day.displayName)
                        .font(.headline)
                        .padding(.vertical, 8)

                    // List of schedules for the day
                    ForEach(viewModel.getSchedules(for: day), id: \.self) { schedule in
                        ClassScheduleRow(schedule: schedule)
                    }

                    // Add schedule button
                    Button(action: {
                        viewModel.addSchedule(for: day)
                    }) {
                        Label("Add \(day.displayName) Schedule", systemImage: "plus.circle.fill")
                    }
                    .padding(.vertical, 8)

                    Divider()
                }
            }

            Button("Save") {
                saveSchedule()
            }
            .disabled(!isSaveEnabled)
        }
    }

    private func saveSchedule() {
        guard selectedIsland != nil else {
            print("Error: Selected island is nil.")
            return
        }

        // Save details for each selected day
        viewModel.saveAllSchedules()
    }
}


struct AddOpenMatFormView_Previews: PreviewProvider {
    @State static var selectedIsland: PirateIsland? = PirateIsland() // Provide a dummy PirateIsland object

    static var previews: some View {
        AddOpenMatFormView(viewModel: AppDayOfWeekViewModel(selectedIsland: selectedIsland), selectedIsland: $selectedIsland)
    }
}
