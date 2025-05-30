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
    
    @State private var successMessage: String?
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false

    
    
    @State private var editingMatTime: MatTime?
    @State private var showEditModal = false
    
    private let fetchQueue = DispatchQueue(label: "fetch-queue")

    var body: some View {
        Section(header: Text("Scheduled Mat Times")) {
            if let error = error {
                Text("⚠️ \(error)").foregroundColor(.red)
            } else if !matTimes.isEmpty {
                MatTimesList(day: day, matTimes: matTimes,
                             onEdit: { matTime in
                                 showEditSheet(for: matTime)
                             },
                             onDelete: { matTime in
                                 deleteMatTime(matTime)
                             })
            } else {
                Text("No mat times have been entered for \(day.rawValue.capitalized) at \(island.islandName ?? "this gym").")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            fetchMatTimes(day: self.day)
        }
        .onChange(of: selectedDay) { _, _ in fetchMatTimes(day: self.selectedDay ?? self.day) }
        .onChange(of: island) { _, _ in fetchMatTimes(day: self.selectedDay ?? self.day) }
        .alert(isPresented: $showSuccessAlert) {
            Alert(title: Text("Success"),
                  message: Text(successMessage ?? "Update completed successfully."),
                  dismissButton: .default(Text("OK")) { successMessage = nil })
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"),
                  message: Text(error ?? "Something went wrong."),
                  dismissButton: .default(Text("OK")) { error = nil })
        }
        .sheet(isPresented: $showEditModal) {
            if let editingMatTime = editingMatTime {
                EditMatTimeView(matTime: editingMatTime) { updatedMatTime in
                    updateMatTime(updatedMatTime)
                    showEditModal = false
                }
            }
        }
    }

    func showEditSheet(for matTime: MatTime) {
        editingMatTime = matTime
        showEditModal = true
    }
    
    func fetchMatTimes(day: DayOfWeek) {
        Task {
            do {
                let fetchedMatTimes = try viewModel.fetchMatTimes(for: day)
                
                let filteredMatTimes = filterMatTimes(fetchedMatTimes, for: day, and: island)
                let sortedMatTimes = sortMatTimes(filteredMatTimes)
                
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
            }
        }
    }

    func filterMatTimes(_ matTimes: [MatTime], for day: DayOfWeek, and island: PirateIsland) -> [MatTime] {
        return matTimes.filter {
            guard let appDayOfWeek = $0.appDayOfWeek else { return false }
            return appDayOfWeek.pIsland?.islandID == island.islandID &&
                   appDayOfWeek.day.caseInsensitiveCompare(day.rawValue) == .orderedSame
        }
    }
    
    

    func sortMatTimes(_ matTimes: [MatTime]) -> [MatTime] {
        return matTimes.sorted { $0.time ?? "" < $1.time ?? "" }
    }
    
    func deleteMatTime(_ matTime: MatTime) {
        Task {
            do {
                try await viewModel.removeMatTime(matTime)
                fetchMatTimes(day: self.selectedDay ?? self.day)
            } catch {
                await MainActor.run {
                    self.error = "Failed to delete mat time: \(error.localizedDescription)"
                }
            }
        }
    }

    
    func updateMatTime(_ updatedMatTime: MatTime) {
        Task {
            do {
                try await viewModel.updateMatTime(updatedMatTime)
                await MainActor.run {
                    self.successMessage = "Mat time updated successfully!"
                    self.showSuccessAlert = true
                }
                fetchMatTimes(day: self.selectedDay ?? self.day)
            } catch {
                await MainActor.run {
                    self.error = "Failed to update mat time: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }

    
}


struct MatTimesList: View {
    let day: DayOfWeek
    let matTimes: [MatTime]

    // Callbacks for edit and delete actions
    var onEdit: ((MatTime) -> Void)?
    var onDelete: ((MatTime) -> Void)?

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

                    // Edit & Delete buttons
                    HStack {
                        Spacer()
                        Button(action: {
                            onEdit?(matTime)
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        Button(action: {
                            onDelete?(matTime)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
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

/*
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
*/
