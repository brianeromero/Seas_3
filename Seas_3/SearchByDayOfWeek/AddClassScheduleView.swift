//
//  AddClassScheduleView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct AddClassScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel // Changed to @ObservedObject
    @Binding var isPresented: Bool
    @State private var selectedDay: DayOfWeek = .monday
    @State private var matTime: String = ""
    @State private var matType: String = ""
    @State private var gi: Bool = false
    @State private var noGi: Bool = false
    @State private var openMat: Bool = false
    @State private var restrictions: Bool = false
    @State private var restrictionDescription: String = ""
    @State private var goodForBeginners: Bool = false
    @State private var adult: Bool = false

    // Ensure that the initializer is accessible
    init(viewModel: AppDayOfWeekViewModel, isPresented: Binding<Bool>) {
        _viewModel = ObservedObject(wrappedValue: viewModel) // Use ObservedObject here
        _isPresented = isPresented
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Class Details")) {
                    Picker("Select Day", selection: $selectedDay) {
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            Text(day.rawValue.capitalized).tag(day)
                        }
                    }
                    
                    TextField("Mat Time", text: $matTime)
                    TextField("Mat Type", text: $matType)
                    
                    Toggle("GI", isOn: $gi)
                    Toggle("No GI", isOn: $noGi)
                    Toggle("Open Mat", isOn: $openMat)
                    Toggle("Restrictions", isOn: $restrictions)
                    if restrictions {
                        TextField("Restriction Description", text: $restrictionDescription)
                    }
                    
                    Toggle("Good for Beginners", isOn: $goodForBeginners)
                    Toggle("Adult", isOn: $adult)
                }
                
                Button(action: {
                    viewModel.addOrUpdateMatTime(time: matTime, type: matType, gi: gi, noGi: noGi, openMat: openMat, restrictions: restrictions, restrictionDescription: restrictionDescription, goodForBeginners: goodForBeginners, adult: adult, for: selectedDay)
                    isPresented = false
                }) {
                    Text("Save")
                }
                .disabled(matTime.isEmpty || matType.isEmpty)
            }
        }
        .onAppear {
            viewModel.initializeNewMatTime()
        }
    }
}

struct AddClassScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        // Initialize AppDayOfWeekRepository with the preview PersistenceController
        let mockRepository = AppDayOfWeekRepository(persistenceController: persistenceController)
        
        // Initialize AppDayOfWeekViewModel with mock data
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: nil, // Set to nil or a mock island if needed
            repository: mockRepository
        )
        
        // Provide a constant binding for `isPresented`
        let isPresented = Binding<Bool>(
            get: { true },
            set: { _ in }
        )

        return AddClassScheduleView(viewModel: viewModel, isPresented: isPresented)
            .environment(\.managedObjectContext, context)
            .previewDisplayName("Add Class Schedule Preview")
    }
}
