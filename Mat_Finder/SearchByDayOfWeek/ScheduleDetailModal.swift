//  ScheduleDetailModal.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/8/24.
//

import SwiftUI

struct ScheduleDetailModal: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    var day: DayOfWeek

    var body: some View {
        VStack(alignment: .leading) {
            Text(day.displayName)
                .font(.largeTitle)
                .bold()
                .padding(.bottom)

            ForEach(viewModel.appDayOfWeekList.filter { $0.day == day.rawValue }, id: \.self) { schedule in
                if let matTimes = schedule.matTimes {
                    ForEach(matTimes.compactMap { $0 as? MatTime }, id: \.self) { matTime in
                        scheduleView(for: matTime)
                    }
                }
            }
        }
        .padding()
        .navigationBarTitle("Schedule Details", displayMode: .inline)
    }

    func scheduleView(for matTime: MatTime) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(matTime.time ?? "Unknown time")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text(matTime.goodForBeginners ? "Beginners" : "")
                    .font(.caption)
                    .foregroundColor(.green)
            }
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
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}


/*
struct ScheduleDetailModal_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        
        // Create mock data for AppDayOfWeek and MatTime
        let mockSchedule1 = AppDayOfWeek(context: persistenceController.container.viewContext)
        let mockMatTime1 = MatTime(context: persistenceController.container.viewContext)
        mockMatTime1.time = "10:00 AM"
        mockMatTime1.gi = true
        mockMatTime1.noGi = false
        mockMatTime1.openMat = true
        mockMatTime1.restrictions = false
        mockMatTime1.restrictionDescription = nil
        mockMatTime1.goodForBeginners = true
        mockMatTime1.kids = false
        mockSchedule1.day = DayOfWeek.monday.rawValue
        mockSchedule1.matTimes = [mockMatTime1] as NSSet

        let mockSchedule2 = AppDayOfWeek(context: persistenceController.container.viewContext)
        let mockMatTime2 = MatTime(context: persistenceController.container.viewContext)
        mockMatTime2.time = "12:00 PM"
        mockMatTime2.gi = false
        mockMatTime2.noGi = true
        mockMatTime2.openMat = false
        mockMatTime2.restrictions = true
        mockMatTime2.restrictionDescription = "No kids allowed"
        mockMatTime2.goodForBeginners = false
        mockMatTime2.kids = false
        mockSchedule2.day = DayOfWeek.monday.rawValue
        mockSchedule2.matTimes = [mockMatTime2] as NSSet

        // Mock ViewModel with mock data
        let enterZipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: persistenceController
        )
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: MockAppDayOfWeekRepository(persistenceController: persistenceController),
            enterZipCodeViewModel: enterZipCodeViewModel
        )
        viewModel.appDayOfWeekList = [mockSchedule1, mockSchedule2]

        return NavigationView {
            ScheduleDetailModal(viewModel: viewModel, day: .monday)
        }
    }
}
*/
