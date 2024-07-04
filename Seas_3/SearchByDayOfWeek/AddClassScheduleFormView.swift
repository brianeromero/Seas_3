//
//  AddClassScheduleView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct AddClassScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedIsland: PirateIsland?
    var onSave: ((_ selectedAppDayOfWeek: DayOfWeek, _ pIsland: PirateIsland?, _ goodForBeginners: Bool, _ matTime: String?, _ openMat: Bool, _ restrictions: Bool, _ restrictionDescription: String?) -> Void)?

    private var isSaveEnabled: Bool {
        viewModel.selectedDays.count > 0
    }

    var body: some View {
        NavigationView {
            Form {
                daysOfWeekSection
            }
            .navigationBarTitle("Add Class Schedule", displayMode: .inline)
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

            Button(action: {
                saveSchedule()
            }) {
                Text("Save")
            }
            .disabled(!isSaveEnabled)
        }
    }

    private func saveSchedule() {
        guard let selectedIsland = selectedIsland else {
            print("Error: Selected island is nil.")
            return
        }

        // Perform validation and save for each selected day
        for day in viewModel.selectedDays {
            onSave?(day, selectedIsland, viewModel.goodForBeginners, viewModel.matTime, viewModel.openMat, viewModel.restrictions, viewModel.restrictionDescription)
        }
    }
}

struct AddClassScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock selectedIsland
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"
        mockIsland.islandLocation = "Mock Location"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        mockIsland.gymWebsite = URL(string: "https://mockisland.com")
        
        // Create a mock AppDayOfWeekViewModel with mockIsland
        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)
        
        // Provide a constant binding for selectedIsland
        return AddClassScheduleView(viewModel: viewModel, selectedIsland: .constant(mockIsland)) { selectedAppDayOfWeek, pIsland, goodForBeginners, matTime, openMat, restrictions, restrictionDescription in
            // Perform any action needed with the saved data
            print("Saved schedule for \(selectedAppDayOfWeek.displayName)")
        }
        .environment(\.managedObjectContext, context)
    }
}
