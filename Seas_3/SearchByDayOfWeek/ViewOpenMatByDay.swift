//
//  ViewOpenMatByDay.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

class DaysOfWeekMenu: ObservableObject {
    enum DayOfWeek: String, CaseIterable, Identifiable {
        case sunday = "Sunday"
        case monday = "Monday"
        case tuesday = "Tuesday"
        case wednesday = "Wednesday"
        case thursday = "Thursday"
        case friday = "Friday"
        case saturday = "Saturday"

        var id: String { self.rawValue }

        var displayName: String {
            return self.rawValue
        }
    }
    
    
    @Published var selectedDay: DayOfWeek? = nil {
        didSet {
            print("Selected day changed to: \(selectedDay?.displayName ?? "nil")")
        }
    }

    var contentView: some View {
        switch selectedDay {
        case .sunday:
            return AnyView(DayDetailView(day: .sunday))
        case .monday:
            return AnyView(DayDetailView(day: .monday))
        case .tuesday:
            return AnyView(DayDetailView(day: .tuesday))
        case .wednesday:
            return AnyView(DayDetailView(day: .wednesday))
        case .thursday:
            return AnyView(DayDetailView(day: .thursday))
        case .friday:
            return AnyView(DayDetailView(day: .friday))
        case .saturday:
            return AnyView(DayDetailView(day: .saturday))
        case .none:
            return AnyView(EmptyView())
        }
    }
}

struct DayDetailView: View {
    let day: DaysOfWeekMenu.DayOfWeek

    var body: some View {
        // Print statement to log the day being displayed
        print("Rendering detail view for \(day.displayName)")
        return Text("Detail view for \(day.displayName)")
            .font(.title)
            .padding()
    }
}

struct DaysOfWeekView: View {
    @ObservedObject var menu = DaysOfWeekMenu()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Select a day to find Open Mats held on a specific day of the week")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)

                List {
                    ForEach(DaysOfWeekMenu.DayOfWeek.allCases) { day in
                        NavigationLink(
                            destination: DayDetailView(day: day),
                            tag: day,
                            selection: $menu.selectedDay
                        ) {
                            HStack {
                                Text(day.displayName) // Use displayName here
                                    .padding(.leading, 10)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                menu.contentView
                    .padding(.horizontal)
            }
            .padding(.horizontal)
            .navigationTitle("By Days of the Week")
        }
    }
}


struct DaysOfWeekView_Previews: PreviewProvider {
    static var previews: some View {
        DaysOfWeekView()
    }
}
