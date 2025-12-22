//
//  ScheduleFormView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/30/24.
//

import SwiftUI
import CoreData
import UIKit
import Combine


// MARK: - Date <-> String conversions using centralized formatter
extension Date {
    func toTimeString() -> String {
        AppDateFormatter.twelveHour.string(from: self)
    }
}

extension String {
    func toTimeDate() -> Date? {
        AppDateFormatter.twelveHour.date(from: self)
    }
}

// MARK: - MatTime description
extension MatTime {
    override public var description: String {
        guard let timeString = time,
              let date = timeString.toTimeDate() else { return "" }

        return """
        \(date.toTimeString()) \
        - Gi: \(gi), \
        No Gi: \(noGi), \
        Open Mat: \(openMat), \
        Restrictions: \(restrictions), \
        Good for Beginners: \(goodForBeginners), \
        Kids: \(kids)
        """
    }
}


struct ScheduleFormView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let islands: [PirateIsland]

    @Binding var selectedIsland: PirateIsland?
    @Binding var matTimes: [MatTime]

    @ObservedObject var viewModel: AppDayOfWeekViewModel

    @State private var selectedDay: DayOfWeek?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    @State private var showReview = false

    @State private var isLoading = false
    @State private var isAppDayOfWeekLoaded = false
    
    
    var body: some View {
        Form {

            // MARK: - Island Selection
            IslandSection(
                islands: islands,
                selectedIsland: $selectedIsland,
                showReview: $showReview
            )
            .onAppear { Task { await handleOnAppear() } }
            .onChange(of: selectedIsland) { _, _ in Task { await setupInitialSelection() } }

            // MARK: - Day Selection
            daySelectionSection

            // MARK: - Add New Mat Time Section (FIELDS + BUTTON)
            Section {
                AddNewMatTimeSection(
                    selectedIsland: $selectedIsland,
                    selectedDay: $selectedDay,
                    viewModel: viewModel,
                    selectIslandAndDay: { island, day in
                        await selectIslandAndDay(island, day)
                    },
                    showAlert: $showingAlert,      // pass parent binding
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage
                )

                // Always enabled button
                Button(action: {
                    // Call section’s addNewMatTime() via binding if needed
                    NotificationCenter.default.post(name: .addNewMatTimeTapped, object: nil)
                }) {
                    Text("Add New Mat Time")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            // MARK: - Scheduled Mat Times
            if let island = selectedIsland, let day = selectedDay {
                ScheduledMatTimesSection(
                    island: island,
                    day: day,
                    viewModel: viewModel,
                    matTimesForDay: $viewModel.matTimesForDay,
                    selectedDay: $selectedDay
                )
            } else {
                Text("Please select a day and gym to view schedule.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Schedule Entry")
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// MARK: - Day Selection Section
private extension ScheduleFormView {

    var daySelectionSection: some View {
        Section(header: Text("Select Day")) {
            Picker("Day", selection: $selectedDay) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Text(day.displayName).tag(day as DayOfWeek?)
                }
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: selectedDay) { _, newDay in
            guard let newDay, let island = selectedIsland else { return }

            Task {
                isLoading = true

                if let appDay = await selectIslandAndDay(island, newDay) {
                    viewModel.selectedAppDayOfWeek = appDay
                    isAppDayOfWeekLoaded = true
                } /*else {
                    viewModel.selectedAppDayOfWeek = nil
                    isAppDayOfWeekLoaded = false
                    alertTitle = "No Schedule Available"
                    alertMessage = "No mat times have been entered for \(newDay.displayName) at \(island.islandName ?? "this gym")."
                    showingAlert = true
                }
*/
                isLoading = false
            }
        }
    }
}

// MARK: - Lifecycle / Setup
private extension ScheduleFormView {

    func handleOnAppear() async {
        if selectedIsland == nil {
            selectedIsland = islands.first
        }
        await setupInitialSelection()
    }

    func setupInitialSelection() async {
        guard let island = selectedIsland else { return }

        let day = selectedDay ?? .monday
        let (_, fetchedMatTimes) = await viewModel.fetchCurrentDayOfWeek(
            for: island,
            day: day,
            selectedDayBinding: Binding(
                get: { viewModel.selectedDay },
                set: { viewModel.selectedDay = $0 }
            )
        )

        if let fetchedMatTimes {
            viewModel.matTimesForDay[day] = fetchedMatTimes
        }

    }
    
    private func formatDateToString(_ date: Date) -> String {
        AppDateFormatter.twelveHour.string(from: date)
    }

    func stringToDate(_ string: String) -> Date? {
        AppDateFormatter.twelveHour.date(from: string)
    }


}

// MARK: - Data Helpers
private extension ScheduleFormView {

    func selectIslandAndDay(_ island: PirateIsland, _ day: DayOfWeek) async -> AppDayOfWeek? {
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(
            format: "pIsland.islandID == %@ AND day == %@",
            island.islandID! as CVarArg,
            day.rawValue
        )

        do {
            return try viewContext.fetch(request).first
        } catch {
            print("❌ Failed to fetch AppDayOfWeek: \(error)")
            return nil
        }
    }

    func addNewMatTime() {
        print("✅ Add New Mat Time tapped")
        // Your existing add logic lives here
    }

    func formatTime(_ time: String) -> String {
        if let date = AppDateFormatter.twelveHour.date(from: time) {
            return AppDateFormatter.twelveHour.string(from: date)
        }
        return time
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
