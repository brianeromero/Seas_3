//
//  DayOfWeekView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct DayOfWeekView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    var pIsland: PirateIsland?

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedTimeText = ""
    @State private var selectedDay: DayOfWeek?

    @State private var showTimePicker = false
    @State private var saveEnabled = false
    @State private var selectedDate = Date()
    @State private var isSaved = false  // Add this line


    var body: some View {
        NavigationView {
            VStack {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Toggle(day.displayName, isOn: viewModel.binding(for: day))
                }
                .padding()

                NavigationLink(
                    destination: SavedConfirmationView(),
                    isActive: $isSaved,
                    label: {
                        EmptyView()
                    }
                )
            }
            .onAppear {
                viewModel.fetchCurrentDayOfWeek()
                Logger.log("View appeared", view: "DayOfWeekView")
            }
            .navigationTitle("Day of Week Settings")
        }
    }
}

struct DayOfWeekView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"

        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        return DayOfWeekView(viewModel: viewModel, selectedAppDayOfWeek: .constant(nil), pIsland: mockIsland)
            .environment(\.managedObjectContext, context)
    }
}
