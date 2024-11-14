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
        .onAppear(perform: {
            fetchMatTimes(day: self.day)
            print("View appeared")
        })
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
            return appDayOfWeek.pIsland?.islandID == island.islandID && appDayOfWeek.day.caseInsensitiveCompare(day.rawValue) == .orderedSame
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
        .navigationBarTitle(Text("Scheduled Mat Times for \(day.rawValue.capitalized)"))
    }
}

func debugPrintMatTimes(_ matTimes: [MatTime]) {
    for matTime in matTimes {
        debugPrint("MatTime: \(matTime.time ?? "Unknown"), GI: \(matTime.gi)")
    }
}


struct ScheduledMatTimesSectionPreview_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        
        // Create a PirateIsland object
        let island = PirateIsland(context: persistenceController.container.viewContext)
        island.islandID = UUID()
        island.islandName = "Black Pearl Academy"
        
        // Create AppDayOfWeek object for Monday
        let monday = AppDayOfWeek(context: persistenceController.container.viewContext)
        monday.day = "Monday"
        monday.pIsland = island

        // Create two MatTime objects for Monday and associate them with the 'monday' AppDayOfWeek
        let morningMatTime = MatTime(context: persistenceController.container.viewContext)
        morningMatTime.time = "10:00 AM"
        morningMatTime.gi = true
        morningMatTime.noGi = false
        morningMatTime.openMat = false
        morningMatTime.restrictions = false
        morningMatTime.goodForBeginners = true
        morningMatTime.kids = false
        morningMatTime.appDayOfWeek = monday

        let noonMatTime = MatTime(context: persistenceController.container.viewContext)
        noonMatTime.time = "12:00 PM"
        noonMatTime.gi = false
        noonMatTime.noGi = true
        noonMatTime.openMat = false
        noonMatTime.restrictions = false
        noonMatTime.goodForBeginners = false
        noonMatTime.kids = true
        noonMatTime.appDayOfWeek = monday

        // Create AppDayOfWeekViewModel with mock data
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: island,
            repository: AppDayOfWeekRepository(persistenceController: persistenceController),
            enterZipCodeViewModel: EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository(persistenceController: persistenceController),
                persistenceController: persistenceController
            )
        )

        // Set up the viewModel's matTimesForDay to reflect the desired setup for Monday
        viewModel.matTimesForDay = [
            DayOfWeek.monday: [morningMatTime, noonMatTime]
        ]
        
        // Set selectedDay to .monday for the preview
        viewModel.selectedDay = DayOfWeek.monday
        
        return NavigationView {
            ScheduledMatTimesSection(
                island: island,
                day: DayOfWeek.monday,
                viewModel: viewModel,
                matTimesForDay: .constant(viewModel.matTimesForDay),
                selectedDay: .constant(viewModel.selectedDay)
            )
        }
        .previewDisplayName("Scheduled Mat Times for Monday Preview")
    }
}
