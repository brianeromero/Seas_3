//
//  ScheduleFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/30/24.
//

import SwiftUI
import CoreData
import UIKit

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

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var daySelected = false
    @State private var selectedDay: DayOfWeek? = .monday // Optional
    @State private var showReview = false
    @State private var showClassScheduleModal = false
    @ObservedObject var daysOfWeekViewModel: DaysOfWeekFormViewModel

    
    
    func setupInitialIsland() {
        if let island = selectedIsland {
            let day = selectedDay ?? .monday
            viewModel.fetchCurrentDayOfWeek(for: island, day: day)
        }
    }

    var body: some View {
        Form {
            IslandSection(
                islands: islands,
                selectedIsland: $selectedIsland,
                showReview: $showReview
            )
            .id(selectedIsland)
            .onAppear {
                print("ScheduleFormView: selectedIsland = \(selectedIsland?.islandName ?? "None")")
                setupInitialIsland()
            }
            .onChange(of: selectedIsland) { newIsland in
                if let island = newIsland {
                    let day = selectedDay ?? .monday
                    viewModel.fetchCurrentDayOfWeek(for: island, day: day)
                }
            }

            daySelectionSection
            addNewMatTimeSection

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
    }
    

    private var daySelectionSection: some View {
        Section(header: Text("Select Day")) {
            Picker("Day", selection: $selectedDay) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Text(day.displayName)
                        .tag(day)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDay) { newDay in
                // Provide a default value if newDay is nil
                let day = newDay ?? .monday
                print("Selected Day: \(day.displayName)")
                viewModel.updateSchedules()
                daySelected = true
                if let island = selectedIsland {
                    viewModel.fetchCurrentDayOfWeek(for: island, day: day)
                }
                selectedAppDayOfWeek = viewModel.currentAppDayOfWeek
            }
            .onAppear {
                if let island = selectedIsland, let day = selectedDay {
                    viewModel.fetchCurrentDayOfWeek(for: island, day: day)
                }
            }
        }
    }

    private var addNewMatTimeSection: some View {
        AddNewMatTimeSection(
            selectedAppDayOfWeek: $selectedAppDayOfWeek,
            selectedDay: Binding(
                get: { selectedDay ?? .monday }, // Provide a default value if `selectedDay` is nil
                set: { newDay in
                    selectedDay = newDay
                }
            ),
            daySelected: $daySelected,
            viewModel: viewModel
        )
    }


    private var errorHandlingSection: some View {
        Group {
            if selectedAppDayOfWeek == nil {
                Section(header: Text("Error")) {
                    Text("No AppDayOfWeek instance selected.")
                        .foregroundColor(.red)
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

struct ScheduleFormView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext
        
        // Create multiple valid PirateIsland objects
        let island1 = PirateIsland(context: context)
        island1.islandID = UUID()
        island1.islandName = "Gym Name 1"
        
        let island2 = PirateIsland(context: context)
        island2.islandID = UUID()
        island2.islandName = "Gym Name 2"
        
        // Create a mock repository for the view model
        let mockRepository = AppDayOfWeekRepository(persistenceController: persistenceController)
        
        // Initialize EnterZipCodeViewModel with mock data
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(repository: mockRepository, context: context)
        
        // Initialize AppDayOfWeekViewModel with mock data
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: island1,
            repository: mockRepository,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        
        // Initialize DaysOfWeekFormViewModel
        let daysOfWeekViewModel = DaysOfWeekFormViewModel()
        
        return ScheduleFormView(
            islands: [island1, island2],
            selectedAppDayOfWeek: .constant(nil),
            selectedIsland: .constant(island1),
            viewModel: viewModel,
            daysOfWeekViewModel: daysOfWeekViewModel
        )
        .environment(\.managedObjectContext, context)
        .previewDisplayName("Schedule Entry Preview")
    }
}
