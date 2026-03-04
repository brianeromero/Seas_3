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
            Text(day.ultraShortDisplayName)
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
                
                if matTime.goodForBeginners {
                    Text("Beginners")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            HStack(spacing: 12) {
                Label("Gi", systemImage: matTime.gi ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(matTime.gi ? .green : .red)
                
                Label("NoGi", systemImage: matTime.noGi ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(matTime.noGi ? .green : .red)
                
                Label("Open Mat", systemImage: matTime.openMat ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(matTime.openMat ? .green : .red)
                
                if matTime.kids {
                    Label("Kids", systemImage: "person.fill")
                        .foregroundColor(.purple)
                }
                
                if matTime.womensOnly {   // ✅ NEW
                    Label("Women’s Only", systemImage: "person.2.fill")
                        .foregroundColor(.pink)
                }
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

