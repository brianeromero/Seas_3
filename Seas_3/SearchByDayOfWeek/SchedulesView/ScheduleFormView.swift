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
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a" // Ensure consistent format
    return formatter.string(from: date)
}

private func stringToDate(_ string: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.date(from: string)
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
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedIsland: PirateIsland? // Binding to the selectedIsland
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var matTimes: [MatTime]
    @State private var error: String?

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var daySelected = false
    @State private var selectedDay: DayOfWeek? = nil
    @State private var showReview = false
    @State private var showClassScheduleModal = false
    
    // Add these two missing state properties
    @State private var isLoading = false
    @State private var isAppDayOfWeekLoaded = false

    var body: some View {
        Form {
            IslandSection(
                islands: islands,
                selectedIsland: $selectedIsland,
                showReview: $showReview
            )
            .id(selectedIsland)
            .onAppear {
                print("Selected Island: \(selectedIsland?.islandName ?? "No island selected")")
                Task {
                    await handleOnAppear()
                }
            }
            .onChange(of: selectedIsland) { oldIsland, newIsland in
                print("Island changed from \(String(describing: oldIsland)) to \(String(describing: newIsland))")
                Task {
                    await setupInitialSelection()
                }
            }

            .onChange(of: selectedAppDayOfWeek) { oldValue, newValue in
                print("AppDayOfWeek changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
            }

            .onChange(of: viewModel.matTimesForDay) { oldMatTimes, newMatTimes in
                print("MatTimes changed from \(oldMatTimes) to \(newMatTimes)")
            }


            daySelectionSection

            AddNewMatTimeSection(
                selectedIsland: $selectedIsland,
                selectedDay: $selectedDay,
                daySelected: $daySelected,
                viewModel: viewModel,
                selectIslandAndDay: selectIslandAndDay
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
        }
        .navigationTitle("Schedule Entry")
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            print("Selected Island: \(selectedIsland?.islandName ?? "No island selected")")
            Task {
                await logInitialSetup()
            }
        }
    }
    
    private func handleOnAppear() async {
        if selectedIsland == nil, let firstIsland = islands.first {
            selectedIsland = firstIsland // Ensure a default selection
        }
        
        print("handleOnAppear - Selected Island: \(selectedIsland?.islandName ?? "No island selected")")

        await setupInitialSelection() // Ensure this runs after selecting an island
    }

    private func logInitialSetup() async {
        if let island = selectedIsland {
            let day = selectedDay ?? .monday
            
            let (_, matTimes) = await viewModel.fetchCurrentDayOfWeek(
                for: island,
                day: day,
                selectedDayBinding: .init(get: { viewModel.selectedDay }, set: { viewModel.selectedDay = $0 ?? .monday })
            )

            // Directly update @Published properties (already on main thread)
            if let matTimes = matTimes {
                viewModel.matTimesForDay[day] = matTimes
            }

            print("Initial island set: \(island.islandName ?? ""), day: \(day)")
        }
    }

    private func setupInitialSelection() async {
        await updateDayOfWeek()
    }

    func updateDayOfWeek() async {
        if let island = selectedIsland, let day = selectedDay {
            _ = await viewModel.fetchCurrentDayOfWeek(
                for: island,
                day: day,
                selectedDayBinding: Binding(get: { viewModel.selectedDay }, set: { viewModel.selectedDay = $0 })
            )
            print("Initial island set: \(island.islandName ?? ""), day: \(day)")
        }
    }

    private var selectedDayBinding: Binding<DayOfWeek> {
        Binding(get: {
            selectedDay ?? .monday // default value
        }, set: { selectedDay = $0 })
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
        .onChange(of: selectedDay) { oldDay, newDay in
            guard let newDay = newDay else {
                print("No day selected.")
                return
            }

            daySelected = true
            print("Selected day changed from \(oldDay?.displayName ?? "No previous day") to \(newDay.displayName)")

            if let selectedIsland = selectedIsland {
                Task {
                    isLoading = true
                    if let appDayOfWeek = await selectIslandAndDay(selectedIsland, newDay) {
                        // ✅ If schedule exists, update the view model
                        viewModel.selectedAppDayOfWeek = appDayOfWeek
                        isAppDayOfWeekLoaded = true
                    } else {
                        // 🛑 No schedule exists, show the proper message
                        viewModel.selectedAppDayOfWeek = nil
                        isAppDayOfWeekLoaded = false
                        alertTitle = "No Schedule Available"
                        alertMessage = "No mat times available or have been entered for \(newDay.displayName) at \(selectedIsland.islandName ?? "this gym")."
                        showingAlert = true
                    }
                    isLoading = false
                }
            } else {
                print("Invalid island selected.")
            }
        }

    }


    func selectIslandAndDay(_ island: PirateIsland, _ day: DayOfWeek) async -> AppDayOfWeek? {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()

        // Use the correct relationship name (pIsland)
        request.predicate = NSPredicate(format: "pIsland.islandID == %@ AND day == %@", island.islandID! as any CVarArg as CVarArg, day.rawValue)

        do {
            let results = try context.fetch(request)
            return results.first // Return the first matching AppDayOfWeek or nil
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error)")
            return nil
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
            selectedIsland: .constant(sampleIsland),
            viewModel: viewModel,
            matTimes: .constant([morningMatTime, noonMatTime])
        )
        .previewDisplayName("Schedule Form View with Sample Data")
    }
}
