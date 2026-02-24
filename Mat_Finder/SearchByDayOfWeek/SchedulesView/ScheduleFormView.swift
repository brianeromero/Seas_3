//
//  NEW ScheduleFormView.swift
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
    
    @Environment(\.managedObjectContext)
    private var viewContext
    
    let islands: [PirateIsland]
    
    @State private var selectedIslandID: String?
    
    var selectedIsland: PirateIsland? {
        islands.first { $0.islandID == selectedIslandID }
    }
    
    let initialSelectedIsland: PirateIsland?
    
    @Binding var matTimes: [MatTime]
    
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    
    
    // MARK: VIEW STATE
    
    @State private var selectedDay: DayOfWeek? = nil
    
    @State private var showingAddSchedule = false
    
    
    // Alerts
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var showReview = false
    
    
    // MARK: BODY
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 24) {   // ✅ FIX HERE

            islandSection
            
            viewDaySection
            
            scheduleListSection
                        
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Schedule")

        // ✅ ADD IT RIGHT HERE
        .safeAreaInset(edge: .bottom) {

            addScheduleButton
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)

        }

        .onAppear {

            viewModel.selectedDay = selectedDay ?? .monday

            Task {
                await handleOnAppear()
            }

        }
        
        .sheet(isPresented: $showingAddSchedule) {
            
            NavigationStack {
                
                AddNewMatTimeSection2(
                    selectedIslandID: $selectedIslandID,
                    islands: islands,
                    viewModel: viewModel,
                    showAlert: $showingAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    selectIslandAndDay: selectIslandAndDay
                )
                
            }
            
        }
        
        .alert(isPresented: $showingAlert) {
            
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
            
        }
        
    }
}


 

// MARK: -addScheduleButton

private extension ScheduleFormView {

    var addScheduleButton: some View {

        Button {

            showingAddSchedule = true

        } label: {

            HStack {

                Image(systemName: "plus.circle.fill")

                Text("Add Schedule")

            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private extension ScheduleFormView {

    var islandSection: some View {

        IslandSection(
            islands: islands,
            selectedIslandID: $selectedIslandID,
            showReview: $showReview
        )

    }

}

private extension ScheduleFormView {

    var scheduleListSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            if let island = selectedIsland,
               let selectedDay {

                let matTimes = viewModel.matTimesForDay[selectedDay] ?? []

                if matTimes.isEmpty {

                    Text("""
                    No mat times entered for \(selectedDay.displayName) at \(island.islandName ?? "").

                    Click the button below to add schedule.
                    """)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 12)
                    
                } else {

                    ScheduledMatTimesSection(
                        island: island,
                        day: selectedDay,
                        viewModel: viewModel,
                        matTimesForDay: $viewModel.matTimesForDay,
                        selectedDay: Binding(
                            get: { selectedDay },
                            set: { self.selectedDay = $0 }
                        )
                    )

                    Text("Click the button below to edit or add schedule.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)   // ✅ ADD HERE

                }

            } else {

                Text("Click the Button Below to Add Schedule.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)   // ✅ ADD HERE

            }

            Spacer()

        }
        .frame(maxWidth: .infinity, alignment: .top)

    }

}

private extension ScheduleFormView {

    var viewDaySection: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Select a Day to View Available Mat Times")
                .font(.caption)
                .foregroundColor(.secondary)

            ScheduleDaySelector(
                island: selectedIsland,
                selectedDay: $selectedDay,
                viewModel: viewModel
            )
            .onChange(of: selectedDay) { _, newDay in

                guard let newDay else { return }

                viewModel.selectedDay = newDay

                Task {
                    await setupInitialSelection()
                }

            }

        }
    }
}

// MARK: - Lifecycle / Setup
private extension ScheduleFormView {

    func handleOnAppear() async {

        // 🧪 DEBUG — add temporarily
        print("🧭 initialSelectedIsland:",
              initialSelectedIsland?.islandName ?? "nil")
        print("🧭 selectedIslandID (before):",
              selectedIslandID ?? "nil") // ✅ no .uuidString

        if selectedIslandID == nil {
            if let initial = initialSelectedIsland {
                selectedIslandID = initial.islandID // String? ✅
            } else if let first = islands.first {
                selectedIslandID = first.islandID // String? ✅
            }
        }

        print("🧭 selectedIslandID (after):",
              selectedIslandID ?? "nil") // ✅ no .uuidString

        await setupInitialSelection()
    }


    func setupInitialSelection() async {

        guard let island = selectedIsland else { return }
        guard let day = selectedDay else { return }

        let (_, fetchedMatTimes) =
        await viewModel.fetchCurrentDayOfWeek(
            for: island,
            day: day,
            selectedDayBinding: Binding(
                get: { viewModel.selectedDay },
                set: { viewModel.selectedDay = $0 }
            )
        )

        if let fetchedMatTimes {

            await MainActor.run {

                viewModel.matTimesForDay[day] = fetchedMatTimes

            }

        }

    }

}

// MARK: - Data Helpers
private extension ScheduleFormView {

    func selectIslandAndDay(_ island: PirateIsland, _ day: DayOfWeek) async -> AppDayOfWeek? {
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        
        // ✅ Safely unwrap islandID
        guard let islandID = island.islandID else {
            print("❌ Island has no islandID")
            return nil
        }

        request.predicate = NSPredicate(
            format: "pIsland.islandID == %@ AND day == %@",
            islandID,
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
