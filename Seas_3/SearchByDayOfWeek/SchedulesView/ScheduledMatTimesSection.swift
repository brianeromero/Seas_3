//
//  ScheduledMatTimesSection.swift
//  Seas_3
//
//  Created by Brian Romero on 8/26/24.
//

import Foundation
import SwiftUI
import CoreData

struct ScheduledMatTimesSection: View {
    let island: PirateIsland
    let day: DayOfWeek
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var matTimesForDay: [DayOfWeek: [MatTime]]
    @Binding var selectedDay: DayOfWeek?
    @State private var matTimes: [MatTime] = []
    @State private var error: String?

    
    private let fetchQueue = DispatchQueue(label: "fetch-queue")
    
    var body: some View {
        Section(header: Text("Scheduled Mat Times")) {
            Group {
                if !matTimes.isEmpty {
                    MatTimesList(day: day, matTimes: matTimes)
                } else {
                    Text("No mat times available for \(day.rawValue.capitalized) at \(island.islandName ?? "this gym").")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear(perform: { fetchMatTimes(day: self.day) })
        .onChange(of: selectedDay) { _, _ in fetchMatTimes(day: self.selectedDay ?? self.day) }
        .onChange(of: island) { _, _ in fetchMatTimes(day: self.selectedDay ?? self.day) }
        .alert(isPresented: .init(get: { error != nil }, set: { _ in error = nil })) {
            Alert(title: Text("Error"), message: Text(error ?? ""))
        }
    }
    
    func fetchMatTimes(day: DayOfWeek) {
        Task {
            do {
                let fetchedMatTimes = try viewModel.fetchMatTimes(for: day)
                print("FROM SCHEDULEDMATTIMESSECTION: Fetched Mat Times: \(fetchedMatTimes)")
                
                let filteredMatTimes = filterMatTimes(fetchedMatTimes, for: day, and: island)
                print("Filtered Mat Times: \(filteredMatTimes)")
                
                let sortedMatTimes = sortMatTimes(filteredMatTimes)
                print("Sorted Mat Times: \(sortedMatTimes)")
                
                await MainActor.run {
                    self.matTimes = sortedMatTimes
                    self.viewModel.matTimesForDay[self.selectedDay ?? day] = sortedMatTimes
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.matTimes = []
                    self.error = error.localizedDescription
                }
                print("Error fetching mat times: \(error)")
            }
        }
    }

    func filterMatTimes(_ matTimes: [MatTime], for day: DayOfWeek, and island: PirateIsland) -> [MatTime] {
        return matTimes.filter {
            guard let appDayOfWeek = $0.appDayOfWeek else { return false }
            return appDayOfWeek.pIsland?.islandID == island.islandID && appDayOfWeek.day?.caseInsensitiveCompare(day.rawValue) == .orderedSame
        }
    }

    func sortMatTimes(_ matTimes: [MatTime]) -> [MatTime] {
        return matTimes.sorted { $0.time ?? "" < $1.time ?? "" }
    }
}

struct MatTimesList: View {
    let day: DayOfWeek
    let matTimes: [MatTime]

    var body: some View {
        List {
            ForEach(matTimes, id: \.objectID) { matTime in
                VStack(alignment: .leading) {
                    if let timeString = matTime.time {
                        Text("Time: \(DayOfWeek.formatTime(from: timeString))")
                            .font(.headline)
                    } else {
                        Text("Time: Unknown")
                            .font(.headline)
                    }
                    HStack {
                        if matTime.gi {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Gi")
                            }
                        }
                        if matTime.noGi {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("NoGi")
                            }
                        }
                        if matTime.openMat {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Open Mat")
                            }
                        }
                    }
                    
                    if matTime.restrictions {
                        Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        if matTime.goodForBeginners {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Good for Beginners")
                            }
                        }
                        if matTime.kids {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Kids Class")
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            debugPrintMatTimes(matTimes)
        }
        .navigationBarTitle(Text("Scheduled Mat Times for \(day.rawValue.capitalized)"))
    }
}

func debugPrintMatTimes(_ matTimes: [MatTime]) {
    for matTime in matTimes {
        debugPrint("MatTime: \(matTime.time ?? "Unknown"), GI: \(matTime.gi)")
    }
}

struct ScheduledMatTimesSection_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext
        
        // Create a PirateIsland object
        let island = PirateIsland(context: context)
        island.islandID = UUID()
        island.islandName = "Gym Name"
        
        // Create AppDayOfWeek objects
        let monday = AppDayOfWeek(context: context)
        monday.day = "Monday"
        monday.pIsland = island
        
        let tuesday = AppDayOfWeek(context: context)
        tuesday.day = "Tuesday"
        tuesday.pIsland = island
        
        // Create MatTime objects
        let mondayMatTime1 = MatTime(context: context)
        mondayMatTime1.time = "10:00 AM"
        mondayMatTime1.gi = true
        mondayMatTime1.noGi = false
        mondayMatTime1.openMat = false
        mondayMatTime1.restrictions = false
        mondayMatTime1.goodForBeginners = true
        mondayMatTime1.kids = false
        mondayMatTime1.appDayOfWeek = monday
        
        let mondayMatTime2 = MatTime(context: context)
        mondayMatTime2.time = "12:00 PM"
        mondayMatTime2.gi = false
        mondayMatTime2.noGi = true
        mondayMatTime2.openMat = false
        mondayMatTime2.restrictions = false
        mondayMatTime2.goodForBeginners = false
        mondayMatTime2.kids = true
        mondayMatTime2.appDayOfWeek = monday
        
        let tuesdayMatTime = MatTime(context: context)
        tuesdayMatTime.time = "2:00 PM"
        tuesdayMatTime.gi = true
        tuesdayMatTime.noGi = false
        tuesdayMatTime.openMat = false
        tuesdayMatTime.restrictions = false
        tuesdayMatTime.goodForBeginners = true
        tuesdayMatTime.kids = false
        tuesdayMatTime.appDayOfWeek = tuesday
        
        // Create AppDayOfWeekViewModel
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: island,
            repository: AppDayOfWeekRepository(persistenceController: persistenceController),
            enterZipCodeViewModel: EnterZipCodeViewModel(repository: AppDayOfWeekRepository(persistenceController: persistenceController), context: context)
        )
        
        // Set up matTimesForDay
        var matTimesForDay: [DayOfWeek: [MatTime]] = [:]
        matTimesForDay[.monday] = [mondayMatTime1, mondayMatTime2]
        matTimesForDay[.tuesday] = [tuesdayMatTime]
        
        return ScheduledMatTimesSection(
            island: island,
            day: .monday,
            viewModel: viewModel,
            matTimesForDay: .constant(matTimesForDay),
            selectedDay: .constant(.monday)
        )
        .environment(\.managedObjectContext, context)
        .previewDisplayName("Scheduled Mat Times Section Preview")
    }
}
