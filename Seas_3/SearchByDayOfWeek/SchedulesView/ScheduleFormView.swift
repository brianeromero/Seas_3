//
//  ScheduleFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/30/24.
//

import SwiftUI
import CoreData
import UIKit
import Combine


private func formatDateToString(_ date: Date) -> String {
    return DateFormat.time.string(from: date)
}

private func stringToDate(_ string: String) -> Date? {
    return DateFormat.time.date(from: string)
}



extension MatTime {
    override public var description: String {
        guard let timeString = time, let date = stringToDate(timeString) else { return "" }
        return "\(formatDateToString(date)) - Gi: \(gi), No Gi: \(noGi), Open Mat: \(openMat), Restrictions: \(restrictions), Good for Beginners: \(goodForBeginners), Kids: \(kids)"
    }
}

struct ScheduleFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var islands: [PirateIsland] // Receive islands from parent view
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @State private var cancellable: AnyCancellable?
    @Binding var matTimes: [MatTime]
    @State private var error: String?

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var daySelected = false
    @State private var selectedDay: DayOfWeek? = nil // No default selection
    @State private var showReview = false
    @State private var showClassScheduleModal = false

    var body: some View {
        Form {
            IslandSection(
                islands: islands,
                selectedIsland: $selectedIsland,
                showReview: $showReview
            )
            .id(selectedIsland)
            .onAppear {
                print("ScheduleFormView: selectedIsland = \(String(describing: selectedIsland))")
                setupInitialSelection()
            }
            .onChange(of: selectedIsland) { newIsland in
                setupInitialSelection()
                print("Selected Island changed: \(String(describing: newIsland))")
                if let island = newIsland {
                    let day = selectedDay ?? .monday
                    _ = viewModel.fetchCurrentDayOfWeek(
                        for: island,
                        day: day,
                        selectedDayBinding: Binding(get: { viewModel.selectedDay }, set: { viewModel.selectedDay = $0 })
                    )
                    print("Island changed: \(island.islandName ?? ""), day: \(day)")
                }
            }
            .onChange(of: selectedDay) { _ in
                daySelected = true
                print("ScheduleFormView: Selected day changed to \(selectedDay?.displayName ?? "None")")
            }

            daySelectionSection

            AddNewMatTimeSection(
                selectedIsland: $selectedIsland,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                selectedDay: selectedDayBinding,
                daySelected: $daySelected,
                viewModel: viewModel
            )
            
            if let selectedDay = selectedDay, let selectedIsland = selectedIsland {
                ScheduledMatTimesSection(
                    island: selectedIsland,
                    day: selectedDay,
                    viewModel: viewModel,
                    matTimesForDay: $viewModel.matTimesForDay,
                    selectedDay: $selectedDay
                )
            } else {
                Text("Please select a day and island to view the schedule.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            errorHandlingSection
        }
        .navigationTitle("Schedule Entry")
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            // Setting up the initial island and day selection
            if let island = selectedIsland {
                let day = selectedDay ?? .monday
                _ = viewModel.fetchCurrentDayOfWeek(
                    for: island,
                    day: day,
                    selectedDayBinding: Binding(get: { viewModel.selectedDay }, set: { viewModel.selectedDay = $0 })
                )
                print("Initial island set: \(island.islandName ?? ""), day: \(day)")
            }
        }
    }
    
    private var selectedDayBinding: Binding<DayOfWeek> {
        return Binding(get: {
            guard let selectedDay = selectedDay else {
                return .monday // default value
            }
            return selectedDay
        }, set: { selectedDay = $0 })
    }
    
    func updateDayOfWeek() {
        if let island = selectedIsland, let day = selectedDay {
            _ = viewModel.fetchCurrentDayOfWeek(
                for: island,
                day: day,
                selectedDayBinding: Binding(get: { viewModel.selectedDay }, set: { viewModel.selectedDay = $0 })
            )
            print("Initial island set: \(island.islandName ?? ""), day: \(day)")
        }
    }

    func setupInitialSelection() {
        updateDayOfWeek()
    }

    func handleDayChange(day: DayOfWeek, island: PirateIsland) {
        guard day != selectedDay else { return }
        setupInitialSelection()
        print("Selected Day changed: \(day.displayName)")
        _ = viewModel.fetchCurrentDayOfWeek(
            for: island,
            day: day,
            selectedDayBinding: Binding(get: { viewModel.selectedDay }, set: { viewModel.selectedDay = $0 })
        )
    }

    private var daySelectionSection: some View {
        Section(header: Text("Select Day")) {
            Picker("Day", selection: $selectedDay) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Text(day.displayName).tag(day as DayOfWeek?)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }


    private var errorHandlingSection: some View {
        Group {
            if let error = error {
                Section(header: Text("Error")) {
                    Text(error)
                        .foregroundColor(.red)
                }
            } else if selectedAppDayOfWeek == nil || selectedIsland == nil {
                Section(header: Text("Error")) {
                    if selectedAppDayOfWeek == nil {
                        Text("No AppDayOfWeek instance selected.")
                            .foregroundColor(.red)
                    } else if selectedIsland == nil {
                        Text("No island selected.")
                            .foregroundColor(.red)
                    } else {
                        Text("Unknown error.")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    func formatTime(_ time: String) -> String {
        if let date = DateFormat.time.date(from: time) {
            return DateFormat.shortTime.string(from: date)
        } else {
            return time
        }
    }
}


struct CornerRadiusStyle: ViewModifier {
    let radius: CGFloat
    let corners: UIRectCorner

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.clear, lineWidth: 0)
                    .mask(
                        Rectangle()
                            .padding(.top, corners.contains(.topLeft) || corners.contains(.topRight) ? radius : 0)
                            .padding(.bottom, corners.contains(.bottomLeft) || corners.contains(.bottomRight) ? radius : 0)
                            .padding(.leading, corners.contains(.topLeft) || corners.contains(.bottomLeft) ? radius : 0)
                            .padding(.trailing, corners.contains(.topRight) || corners.contains(.bottomRight) ? radius : 0)
                    )
            )
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        self.modifier(CornerRadiusStyle(radius: radius, corners: corners))
    }
}

// Preview
struct ScheduleFormView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        
        // Create a sample PirateIsland entity
        let sampleIsland = PirateIsland(context: persistenceController.container.viewContext)
        sampleIsland.islandID = UUID()
        sampleIsland.islandName = "Black Pearl Academy"
        sampleIsland.islandLocation = "Tortuga"
        
        // Create an AppDayOfWeek entity linked to the PirateIsland for Monday
        let mondaySchedule = AppDayOfWeek(context: persistenceController.container.viewContext)
        mondaySchedule.day = "Monday"
        mondaySchedule.pIsland = sampleIsland

        // Create two MatTime entities linked to the AppDayOfWeek for Monday
        let morningMatTime = MatTime(context: persistenceController.container.viewContext)
        morningMatTime.time = "10:00 AM"
        morningMatTime.gi = true
        morningMatTime.noGi = false
        morningMatTime.openMat = false
        morningMatTime.restrictions = false
        morningMatTime.goodForBeginners = true
        morningMatTime.kids = false
        morningMatTime.appDayOfWeek = mondaySchedule

        let noonMatTime = MatTime(context: persistenceController.container.viewContext)
        noonMatTime.time = "12:00 PM"
        noonMatTime.gi = false
        noonMatTime.noGi = true
        noonMatTime.openMat = true
        noonMatTime.restrictions = false
        noonMatTime.goodForBeginners = false
        noonMatTime.kids = true
        noonMatTime.appDayOfWeek = mondaySchedule

        // Create a ViewModel instance with the mock repository and zip code view model
        let mockRepository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(repository: mockRepository, persistenceController: persistenceController)
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: sampleIsland,
            repository: mockRepository,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        
        // Initialize viewModel's properties for preview
        viewModel.selectedDay = DayOfWeek.monday
        viewModel.matTimesForDay = [
            DayOfWeek.monday: [morningMatTime, noonMatTime]
        ]

        // Create ScheduleFormView with mock data and bindings
        return ScheduleFormView(
            islands: [sampleIsland],
            selectedAppDayOfWeek: .constant(mondaySchedule),
            selectedIsland: .constant(sampleIsland),
            viewModel: viewModel,
            matTimes: .constant([morningMatTime, noonMatTime])
        )
        .previewDisplayName("Schedule Form View with Sample Data")
    }
}
