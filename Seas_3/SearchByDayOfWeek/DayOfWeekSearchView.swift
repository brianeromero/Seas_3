// DayOfWeekSearchView.swift
// Seas_3
//
// Created by Brian Romero on 8/21/24.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData
import Combine

struct DayOfWeekSearchView: View {
    @Binding var selectedIsland: PirateIsland?
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var region: MKCoordinateRegion
    @Binding var searchResults: [PirateIsland]

    @StateObject private var userLocationMapViewModel = UserLocationMapViewModel()
    @StateObject private var viewModel = AppDayOfWeekViewModel(
        repository: AppDayOfWeekRepository.shared,
        enterZipCodeViewModel: EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: PersistenceController.preview
        )
    )
    @StateObject private var enterZipCodeViewModel = EnterZipCodeViewModel(
        repository: AppDayOfWeekRepository.shared,
        persistenceController: PersistenceController.preview
    )

    init(
        selectedIsland: Binding<PirateIsland?>,
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        region: Binding<MKCoordinateRegion>,
        searchResults: Binding<[PirateIsland]>
    ) {
        _selectedIsland = selectedIsland
        _selectedAppDayOfWeek = selectedAppDayOfWeek
        _region = region
        _searchResults = searchResults
    }


    @State private var radius: Double = 10.0
    @State private var equatableRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var errorMessage: String?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var showModal: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                DayPickerView(selectedDay: $selectedDay)
                    .onChange(of: selectedDay) { _ in
                        Task { await dayOfWeekChanged() }
                    }

                RadiusPicker(selectedRadius: $radius)
                    .onChange(of: radius) { _ in
                        Task { await radiusChanged() }
                    }

                ErrorView(errorMessage: $errorMessage)

                MapViewContainer(equatableRegion: $equatableRegion, appDayOfWeekViewModel: viewModel) { island in
                    handleIslandTap(island: island)
                }
            }
            .sheet(isPresented: $showModal) {
                IslandModalContainer(
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek
                )
            }
            .onAppear {
                setupInitialRegion()
                requestUserLocation()
            }
            .onChange(of: userLocationMapViewModel.userLocation) { newLocation in
                if let location = newLocation {
                    updateRegion(center: location.coordinate)
                    Task { await updateIslandsAndRegion() }
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                updateSelectedIsland(from: newIsland)
            }
        }
    }
    // Helper methods
    private func setupInitialRegion() {
        equatableRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }


    private func requestUserLocation() {
        userLocationMapViewModel.requestLocation()
    }

    private func dayOfWeekChanged() async {
        await updateIslandsAndRegion()
    }

    private func radiusChanged() async {
        await updateIslandsAndRegion()
    }

    private func updateSelectedIsland(from newIsland: PirateIsland?) {
        guard let newIsland = newIsland else { return }
        if let matchingIsland = viewModel.islandsWithMatTimes.map({ $0.0 }).first(where: { $0.islandID == newIsland.islandID }) {
            selectedIsland = matchingIsland
        } else {
            // Handle the case when no matching island is found
            errorMessage = "Island not found in the current selection."
        }
    }

    

    // ErrorView.swift
    struct ErrorView: View {
        @Binding var errorMessage: String?

        var body: some View {
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else {
                EmptyView()
            }
        }
    }
    
    // MapViewContainer.swift (updated)
    struct MapViewContainer: View {
        @Binding var equatableRegion: MKCoordinateRegion
        @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
        let handleIslandTap: (PirateIsland) -> Void

        var body: some View {
            Map(
                coordinateRegion: $equatableRegion,
                annotationItems: appDayOfWeekViewModel.islandsWithMatTimes.map { $0.0 }
            ) { island in
                MapAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude)
                ) {
                    IslandAnnotationView(island: island, handleIslandTap: { handleIslandTap(island) })
                }
            }
        }
    }
    
    
    private func updateRegion(center: CLLocationCoordinate2D) {
        if userLocationMapViewModel.userLocation != nil {
            withAnimation {
                equatableRegion = MapUtils.updateRegion(
                    markers: viewModel.islandsWithMatTimes.map {
                        CustomMapMarker(
                            id: $0.0.islandID ?? UUID(),
                            coordinate: CLLocationCoordinate2D(latitude: $0.0.latitude, longitude: $0.0.longitude),
                            title: $0.0.islandName ?? "Unnamed Gym",
                            pirateIsland: $0.0
                        )
                    },
                    selectedRadius: radius,
                    center: center
                )
            }
        } else {
            errorMessage = "Error updating region: User location is nil"
        }
    }


    private func handleIslandTap(island: PirateIsland) {
        selectedIsland = island
        showModal = true
    }

    private func updateIslandsAndRegion() async {
        guard let selectedDay = selectedDay else {
            errorMessage = "Day of week is not selected."
            return
        }

        print("Fetching islands for day: \(selectedDay)")

        // If fetchIslands doesn't throw errors, remove the do-catch
        await viewModel.fetchIslands(forDay: selectedDay)

        // Check if userLocationMapViewModel.userLocation exists
        if let location = userLocationMapViewModel.userLocation {
            updateRegion(center: location.coordinate)
        }
    }
}

// IslandAnnotationView.swift
struct IslandAnnotationView: View {
    let island: PirateIsland
    let handleIslandTap: () -> Void

    var body: some View {
        Button(action: handleIslandTap) {
            VStack {
                Text(island.islandName ?? "Unnamed Gym")
                    .font(.caption)
                    .padding(5)
                    .background(Color.white)
                    .cornerRadius(5)
                CustomMarkerView()
            }
        }
    }
}

/*
struct DayOfWeekSearchView_Previews: PreviewProvider {
    
    private static func clearExistingData(viewContext: NSManagedObjectContext) {
        // Clear existing PirateIsland data
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PirateIsland.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try viewContext.execute(deleteRequest)
        } catch {
            print("Error clearing existing PirateIsland data: \(error.localizedDescription)")
        }
        
        // Clear existing AppDayOfWeek data
        let fetchRequestAppDayOfWeek: NSFetchRequest<NSFetchRequestResult> = AppDayOfWeek.fetchRequest()
        let deleteRequestAppDayOfWeek = NSBatchDeleteRequest(fetchRequest: fetchRequestAppDayOfWeek)
        do {
            try viewContext.execute(deleteRequestAppDayOfWeek)
        } catch {
            print("Error clearing existing AppDayOfWeek data: \(error.localizedDescription)")
        }
    }
    
    private static func createSampleIslands(_ viewContext: NSManagedObjectContext) -> [PirateIsland] {
        // Create sample islands
        let island1 = PirateIsland(context: viewContext)
        island1.islandID = UUID()
        island1.islandLocation = "Sunnyvale, CA"
        island1.islandName = "Starbucks Gym"
        island1.latitude = 37.385852
        island1.longitude = -122.031517
        
        let island2 = PirateIsland(context: viewContext)
        island2.islandID = UUID()
        island2.islandLocation = "Mountain View, CA"
        island2.islandName = "Google Gym"
        island2.latitude = 37.422408
        island2.longitude = -122.085608
        
        let island3 = PirateIsland(context: viewContext)
        island3.islandID = UUID()
        island3.islandLocation = "San Jose, CA"
        island3.islandName = "Downtown Gym"
        island3.latitude = 37.334772
        island3.longitude = -121.886328
        
        return [island1, island2, island3]
    }
    
    private static func createSampleAppDayOfWeekObjects(_ viewContext: NSManagedObjectContext, islands: [PirateIsland]) {
        // Create sample AppDayOfWeek objects
        let daysOfWeek = ["Monday", "Tuesday", "Wednesday"]
        let matTimes = [["09:00", "17:00"], ["10:00", "18:00"], ["11:00", "19:00"]]
        
        for (index, island) in islands.enumerated() {
            let appDayOfWeek = AppDayOfWeek(context: viewContext)
            appDayOfWeek.day = daysOfWeek[index]
            appDayOfWeek.pIsland = island
            
            let matTimesForDay = matTimes[index]
            
            for time in matTimesForDay {
                let matTime = MatTime(context: viewContext)
                matTime.time = time
                // Set additional properties if needed
                matTime.gi = true
                matTime.noGi = false
                matTime.openMat = false
                matTime.restrictions = false
                matTime.restrictionDescription = nil
                matTime.goodForBeginners = false
                matTime.kids = false
                
                appDayOfWeek.addToMatTimes(matTime)
            }
        }
    }
    
    private static func clearAndCreateSampleData(viewContext: NSManagedObjectContext) {
        clearExistingData(viewContext: viewContext)
        
        let islands = createSampleIslands(viewContext)
        createSampleAppDayOfWeekObjects(viewContext, islands: islands)
        
        // Save the context after creating data
        do {
            try viewContext.save()
        } catch {
            print("Error saving preview data: \(error.localizedDescription)")
        }
    }

    
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let viewContext = persistenceController.container.viewContext
        
        // Ensure sample data is created for previews
        clearAndCreateSampleData(viewContext: viewContext)
        
        let pirateIslands = (try? viewContext.fetch(PirateIsland.fetchRequest())) ?? []
        let mondayAppDayOfWeek = (try? viewContext.fetch(AppDayOfWeek.fetchRequest()))?.first(where: { $0.day == "Monday" }) ?? AppDayOfWeek(context: viewContext)
        
        // Debugging print
        print("Preview - pirateIslands: \(pirateIslands)")
        
        // Ensure correct Binding types and provide the missing view model initialization
        return DayOfWeekSearchView(
            selectedIsland: Binding.constant(pirateIslands.first),
            selectedAppDayOfWeek: Binding.constant(mondayAppDayOfWeek),
            region: Binding.constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.385852, longitude: -122.031517),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )),
            searchResults: Binding.constant(pirateIslands)
        )
        .environment(\.managedObjectContext, viewContext)
    }
}
*/
