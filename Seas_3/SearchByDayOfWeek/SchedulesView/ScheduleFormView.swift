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
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func stringToDate(_ string: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "hh:mm a"
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
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)],
        animation: .default
    ) private var islands: FetchedResults<PirateIsland>

    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedIsland: PirateIsland?
    @StateObject private var viewModel: AppDayOfWeekViewModel

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var daySelected = false
    @State private var selectedDay: DayOfWeek = .monday

    init(
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>,
        viewModel: AppDayOfWeekViewModel
    ) {
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            Form {
                islandSelectionSection
                daySelectionSection
                addNewMatTimeSection
                scheduledMatTimesSection
                errorHandlingSection
            }
            .navigationTitle("Schedule Form")
            .alert(isPresented: $showingAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var islandSelectionSection: some View {
        Section(header: Text("Select Island")) {
            Picker("Select Island", selection: $selectedIsland) {
                ForEach(islands, id: \.self) { island in
                    Text(island.islandName).tag(island)
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                if let island = newIsland {
                    print("Selected Island: \(island.islandName)")
                    viewModel.fetchCurrentDayOfWeek(for: island, day: selectedDay)
                    
                    if let appDayOfWeek = selectedAppDayOfWeek {
                        viewModel.viewContext.delete(appDayOfWeek)
                        viewModel.saveContext()
                        selectedAppDayOfWeek = nil
                    }
                }
            }
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
                print("Selected Day: \(newDay.displayName)")
                viewModel.updateSchedules()
                daySelected = true
                if let island = selectedIsland {
                    viewModel.fetchCurrentDayOfWeek(for: island, day: newDay)
                }
                selectedAppDayOfWeek = viewModel.currentAppDayOfWeek
            }
        }
    }

    private func dayButton(day: DayOfWeek) -> some View {
        Button(action: {
            selectedDay = day
            print("Selected Day: \(day.displayName)")
            viewModel.updateSchedules()
            daySelected = true
            if let island = selectedIsland {
                viewModel.fetchCurrentDayOfWeek(for: island, day: day)
            }
            selectedAppDayOfWeek = viewModel.currentAppDayOfWeek
        }) {
            Text(day.displayName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(selectedDay == day ? Color.white : Color.black)
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(selectedDay == day ? Color.blue : Color.gray.opacity(0.1))
        }
        .cornerRadius(10, corners: {
            if selectedDay == day {
                if day.number == 2 { // Monday
                    return [.topLeft, .bottomLeft]
                } else if day.number == 7 { // Saturday
                    return [.topRight, .bottomRight]
                } else {
                    return [.topLeft, .topRight]
                }
            } else {
                return []
            }
        }())
    }

    private var addNewMatTimeSection: some View {
        AddNewMatTimeSection(
            selectedAppDayOfWeek: $selectedAppDayOfWeek,
            selectedDay: $selectedDay,
            daySelected: $daySelected,
            viewModel: viewModel
        )
    }

    private var scheduledMatTimesSection: some View {
        Section(header: Text("Scheduled Mat Times")) {
            if let matTimes = viewModel.matTimesForDay[selectedDay], !matTimes.isEmpty {
                List {
                    ForEach(matTimes.sorted { $0.time ?? "" < $1.time ?? "" }, id: \.self) { matTime in
                        VStack(alignment: .leading) {
                            Text("Time: \(formatTime(matTime.time ?? "Unknown"))")
                                .font(.headline)
                            HStack {
                                Label("Gi", systemImage: matTime.gi ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(matTime.gi ? .green : .red)
                                Label("NoGi", systemImage: matTime.noGi ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(matTime.noGi ? .green : .red)
                                Label("Open Mat", systemImage: matTime.openMat ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(matTime.openMat ? .green : .red)
                            }
                            if matTime.restrictions {
                                Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if matTime.goodForBeginners {
                                Text("Good for Beginners")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            if matTime.kids {
                                Text("Kids")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                Text("No mat times available.")
                    .foregroundColor(.gray)
            }
        }
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        if let date = dateFormatter.date(from: time) {
            dateFormatter.dateFormat = "h:mm a"
            return dateFormatter.string(from: date)
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
        
        // Create a valid PirateIsland object
        let island = PirateIsland(context: context)
        island.islandID = UUID()
        island.islandName = "Island Name"
        
        // Create a valid AppDayOfWeek object
        let appDayOfWeek = AppDayOfWeek(context: context)
        appDayOfWeek.appDayOfWeekID = UUID().uuidString
        appDayOfWeek.day = DayOfWeek.monday.rawValue
        appDayOfWeek.name = "Schedule Name"
        
        // Create a mock repository for the view model
        let mockRepository = AppDayOfWeekRepository(persistenceController: persistenceController)
        
        return ScheduleFormView(
            selectedAppDayOfWeek: .constant(appDayOfWeek),
            selectedIsland: .constant(island),
            viewModel: AppDayOfWeekViewModel(selectedIsland: island, repository: mockRepository)
        )
        .environment(\.managedObjectContext, context)
        .previewDisplayName("Schedule Form Preview")
    }
}
