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
    
    @State private var navigationPath = NavigationPath()

    
    @StateObject private var userLocationMapViewModel = UserLocationMapViewModel()
    
    // Create one shared EnterZipCodeViewModel instance
    @StateObject private var enterZipCodeViewModel = EnterZipCodeViewModel(
        repository: AppDayOfWeekRepository.shared,
        persistenceController: PersistenceController.shared
    )
    
    // Pass shared enterZipCodeViewModel into AppDayOfWeekViewModel
    @StateObject private var viewModel: AppDayOfWeekViewModel
    
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

        // Initialize viewModel here using the same enterZipCodeViewModel instance
        // Note: we need to create enterZipCodeViewModel before viewModel, so we use a temporary property here
        let enterZipVM = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: PersistenceController.shared
        )
        _enterZipCodeViewModel = StateObject(wrappedValue: enterZipVM)
        _viewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: enterZipVM
        ))
    }

    @State private var radius: Double = 10.0
    @State private var equatableRegionWrapper = EquatableMKCoordinateRegion(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var errorMessage: String?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var showModal: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                DayPickerView(selectedDay: $selectedDay)
                    .onChange(of: selectedDay) { oldValue, newValue in
                        print("selectedDay changed from \(oldValue?.rawValue ?? "nil") to \(newValue?.rawValue ?? "nil")")
                        Task { await dayOfWeekChanged() }
                    }

                ErrorView(errorMessage: $errorMessage)

                // <<-- MAP VIEW FIRST -->>
                MapViewContainer(
                    region: $equatableRegionWrapper,
                    appDayOfWeekViewModel: viewModel
                ) { island in
                    handleIslandTap(island: island)
                }

                // <<-- THEN RADIUS PICKER -->>
                RadiusPicker(selectedRadius: $radius)
                    .onChange(of: radius) { oldValue, newValue in
                        print("RadiusPicker: radius changed from \(oldValue) to \(newValue)")
                        Task { await radiusChanged() }
                    }
            }
            .sheet(isPresented: $showModal) {
                IslandModalContainer(
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    navigationPath: $navigationPath // <-- Add this
                )
            }

            .onAppear {
                print("DayOfWeekSearchView: onAppear triggered.")
                setupInitialRegion()
                requestUserLocation()
            }
            .onChange(of: userLocationMapViewModel.userLocation) { oldValue, newValue in
                if let location = newValue {
                    print("User location updated to \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    updateRegion(center: location.coordinate)
                    Task { await updateIslandsAndRegion() }
                } else {
                    print("User location is nil.")
                }
            }
            .onChange(of: selectedIsland) { oldValue, newValue in
                print("Selected island changed from \(oldValue?.islandName ?? "nil") to \(newValue?.islandName ?? "nil")")
                updateSelectedIsland(from: newValue)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialRegion() {
        equatableRegionWrapper.region = MKCoordinateRegion(
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
        guard let newIsland = newIsland else {
            print("updateSelectedIsland: newIsland is nil.")
            return
        }
        
        if let matchingIsland = viewModel.islandsWithMatTimes.map({ $0.0 }).first(where: { $0.islandID == newIsland.islandID }) {
            selectedIsland = matchingIsland
            print("updateSelectedIsland: Found matching island \(matchingIsland.islandName ?? "") in current selection.")
        } else {
            errorMessage = "Island not found in the current selection."
            print("updateSelectedIsland: Error - Island \(newIsland.islandName ?? "") not found in current selection.")
        }
    }
    
    private func handleIslandTap(island: PirateIsland) {
        selectedIsland = island
        showModal = true
        print("handleIslandTap: Tapped on island \(island.islandName ?? "Unnamed"). Showing modal.")
    }
    
    private func updateIslandsAndRegion() async {
        guard let selectedDay = selectedDay else {
            errorMessage = "Day of week is not selected."
            print("updateIslandsAndRegion: Error - Day of week is not selected.")
            return
        }
        
        print("updateIslandsAndRegion: Fetching islands for day: \(selectedDay)")
        await viewModel.fetchIslands(forDay: selectedDay)
        print("updateIslandsAndRegion: Finished fetching islands. ViewModel has \(viewModel.islandsWithMatTimes.count) islands.")
        
        if let location = userLocationMapViewModel.userLocation {
            updateRegion(center: location.coordinate)
        } else {
            print("updateIslandsAndRegion: User location not available for region update.")
        }
    }
    
    private func updateRegion(center: CLLocationCoordinate2D) {
        if userLocationMapViewModel.userLocation != nil {
            print("updateRegion: User location exists. Calculating new region.")
            print("updateRegion: Number of markers for MapUtils.updateRegion: \(viewModel.islandsWithMatTimes.count)")
            print("updateRegion: Radius: \(radius), Center: \(center.latitude), \(center.longitude)")
            
            withAnimation {
                equatableRegionWrapper.region = MapUtils.updateRegion(
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
            
            print("updateRegion: New equatableRegion center: \(equatableRegionWrapper.region.center.latitude), \(equatableRegionWrapper.region.center.longitude), span: \(equatableRegionWrapper.region.span.latitudeDelta), \(equatableRegionWrapper.region.span.longitudeDelta)")
        } else {
            errorMessage = "Error updating region: User location is nil"
            print("updateRegion: Error - User location is nil, cannot update region.")
        }
    }
}
    

// MARK: - Error View

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



// MARK: - MapViewContainer
struct MapViewContainer: View {
    @Binding var region: EquatableMKCoordinateRegion
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    let handleIslandTap: (PirateIsland) -> Void

    @State private var cameraPosition: MapCameraPosition

    init(
        region: Binding<EquatableMKCoordinateRegion>,
        appDayOfWeekViewModel: AppDayOfWeekViewModel,
        handleIslandTap: @escaping (PirateIsland) -> Void
    ) {
        _region = region
        self.appDayOfWeekViewModel = appDayOfWeekViewModel
        self.handleIslandTap = handleIslandTap
        _cameraPosition = State(initialValue: .region(region.wrappedValue.region))
    }

    var body: some View {
        let currentIslands = appDayOfWeekViewModel.islandsWithMatTimes.map { $0.0 }

        Map(position: $cameraPosition) {
            ForEach(currentIslands) { island in
                Annotation("Gym", coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude), anchor: .center) {
                    IslandAnnotationView(island: island) {
                        handleIslandTap(island)
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
        }
        .onChange(of: region) { oldValue, newValue in
            print("MapViewContainer: region changed.")
            cameraPosition = .region(newValue.region)
        }

        .onAppear {
            print("MapViewContainer.onAppear: Map container appeared.")
            print("  - \(currentIslands.count) islands loaded.")
        }
    }
}



// MARK: - IslandAnnotationView

struct IslandAnnotationView: View {
    let island: PirateIsland
    let handleIslandTap: () -> Void

    var body: some View {
        Button(action: handleIslandTap) {
            VStack(spacing: 4) {
                Text(island.islandName ?? "Unnamed Gym")
                    .font(.caption2)
                    .padding(4)
                    // --- KEY CHANGE HERE for background ---
                    .background(Color(.systemBackground).opacity(0.85)) // Use adaptive system background
                    .cornerRadius(4)
                    // --- KEY CHANGE HERE for foreground text color ---
                    .foregroundColor(.primary) // Use adaptive primary text color

                CustomMarkerView()
            }
            .shadow(radius: 3)
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
