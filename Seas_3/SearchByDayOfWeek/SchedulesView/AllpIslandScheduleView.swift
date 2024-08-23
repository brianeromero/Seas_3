//
//  AllpIslandScheduleView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/12/24.
//

import Foundation
import SwiftUI

struct AllpIslandScheduleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    @State private var showAddMatTimeForm = false
    @State private var selectedMatTime: MatTime?

    var body: some View {
        VStack {
            Text("All Gyms Schedules")
                .font(.title)
                .padding()

            List {
                ForEach(sortedDays, id: \.self) { day in
                    daySection(for: day)
                }
                .onDelete(perform: deleteMatTimes)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem {
                Button(action: {
                    selectedMatTime = nil
                    showAddMatTimeForm = true
                }) {
                    Label("Add MatTime", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMatTimeForm) {
            DaysOfWeekFormView(
                viewModel: viewModel,
                selectedIsland: $viewModel.selectedIsland,
                selectedMatTime: $selectedMatTime // Corrected binding here
            )
        }
        .onAppear {
            Task {
                await viewModel.loadAllSchedules()
            }
        }
    }

    private func daySection(for day: DayOfWeek) -> some View {
        let schedulesForDay = filteredSchedules(for: day)
        
        return Group {
            if !schedulesForDay.isEmpty {
                Section(header: Text(day.displayName)) {
                    ForEach(schedulesForDay, id: \.0) { island, matTimes in
                        islandSection(island: island, matTimes: matTimes)
                    }
                }
            }
        }
    }

    private func islandSection(island: PirateIsland, matTimes: [MatTime]) -> some View {
        Group {
            if !island.islandName.isEmpty {
                Section(header: Text(island.islandName)) {
                    ForEach(filteredAndSortedMatTimes(matTimes), id: \.self) { matTime in
                        ScheduleRow(matTime: matTime)
                            .onTapGesture {
                                selectedMatTime = matTime
                                showAddMatTimeForm = true
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteMatTime(matTime)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    var sortedDays: [DayOfWeek] {
        viewModel.islandSchedules.keys.sorted { $0.rawValue < $1.rawValue }
    }

    func filteredSchedules(for day: DayOfWeek) -> [(PirateIsland, [MatTime])] {
        guard let schedules = viewModel.islandSchedules[day] else {
            return []
        }
        return schedules.filter { !$0.1.filter { $0.appDayOfWeek != nil }.isEmpty }
    }

    func filteredAndSortedMatTimes(_ matTimes: [MatTime]) -> [MatTime] {
        matTimes
            .filter { $0.appDayOfWeek != nil && $0.time != nil && !$0.time!.isEmpty }
            .sorted {
                guard let time1 = DateFormat.mediumDateTime.date(from: $0.time!),
                      let time2 = DateFormat.mediumDateTime.date(from: $1.time!)
                else { return false }
                return time1 < time2
            }
    }

    private func deleteMatTimes(offsets: IndexSet) {
        withAnimation {
            offsets.map { sortedDays[$0] }.forEach { day in
                guard let schedules = viewModel.islandSchedules[day] else { return }
                schedules.forEach { island, matTimes in
                    matTimes.enumerated().filter { offsets.contains($0.offset) }.forEach { matTime in
                        viewContext.delete(matTime.element)
                    }
                }
            }

            do {
                try viewContext.save()
                // Refresh the view model's data after deletion
                Task {
                    await viewModel.loadAllSchedules()
                }
            } catch {
                print("Failed to delete MatTimes: \(error.localizedDescription)")
            }
        }
    }

    private func deleteMatTime(_ matTime: MatTime) {
        viewContext.delete(matTime)
        do {
            try viewContext.save()
            // Refresh the view model's data after deletion
            Task {
                await viewModel.loadAllSchedules()
            }
        } catch {
            print("Failed to delete MatTime: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

struct AllpIslandScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Sample Island"

        let mockAppDayOfWeek = AppDayOfWeek(context: context)
        mockAppDayOfWeek.day = DayOfWeek.monday.rawValue
        mockAppDayOfWeek.pIsland = mockIsland
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        
        let mockMatTime1 = MatTime(context: context)
        mockMatTime1.time = DateFormat.time.string(from: Date().addingTimeInterval(-3600))
        mockAppDayOfWeek.addToMatTimes(mockMatTime1)

        let mockMatTime2 = MatTime(context: context)
        mockMatTime2.time = DateFormat.time.string(from: Date().addingTimeInterval(3600))
        mockAppDayOfWeek.addToMatTimes(mockMatTime2)

        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: AppDayOfWeekRepository(persistenceController: persistenceController)
        )

        return AllpIslandScheduleView(viewModel: viewModel)
            .environment(\.managedObjectContext, context)
    }
}
