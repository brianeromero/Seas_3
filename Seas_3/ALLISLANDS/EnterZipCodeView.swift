import SwiftUI
import CoreLocation
import MapKit
import CoreData

struct EnterZipCodeView: View {
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @State private var locationInput: String = ""
    @State private var searchResults: [PirateIsland] = []
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedIsland: PirateIsland? = nil
    @State private var showModal: Bool = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek? = nil
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var selectedRadius: Double = 5.0 // Radius in miles

    var body: some View {
        NavigationView {
            VStack {
                TextField("Enter Location (Zip Code, Address, City, State)", text: $locationInput)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // Use the reusable RadiusPicker component
                RadiusPicker(selectedRadius: $selectedRadius)

                Button(action: search) {
                    Text("Search")
                }
                .padding()

                // Map View
                IslandMapView(
                    viewModel: appDayOfWeekViewModel,
                    selectedIsland: $selectedIsland,
                    showModal: $showModal,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedDay: $selectedDay,
                    allEnteredLocationsViewModel: allEnteredLocationsViewModel,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    region: $region, // Pass the region as a binding
                    searchResults: $searchResults // Pass the search results as a binding
                )
                .frame(height: 400)
                .onChange(of: searchResults) { _ in
                    if let firstIsland = searchResults.first {
                        self.region.center = CLLocationCoordinate2D(latitude: firstIsland.latitude, longitude: firstIsland.longitude)
                    }
                }
            }
            .padding() // Add padding to match overall view
            .navigationTitle("Enter Location")
        }
        .sheet(isPresented: $showModal) {
            IslandModalContainer(
                selectedIsland: $selectedIsland,
                viewModel: appDayOfWeekViewModel,
                selectedDay: $selectedDay,
                showModal: $showModal,
                enterZipCodeViewModel: enterZipCodeViewModel,
                selectedAppDayOfWeek: $selectedAppDayOfWeek
            )
        }
    }

    private func search() {
        Task {
            do {
                let coordinate = try await MapUtils.fetchLocation(for: locationInput)
                
                // Update the region with the new coordinates
                self.region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: self.selectedRadius * 0.01, // Convert miles to degrees
                        longitudeDelta: self.selectedRadius * 0.01
                    )
                )
                
                // Fetch Pirate Islands near the found location
                self.enterZipCodeViewModel.fetchPirateIslandsNear(
                    CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    within: self.selectedRadius * 1609.34 // Convert miles to meters
                )
                
                // Filter results based on the selected radius
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                self.searchResults = self.enterZipCodeViewModel.pirateIslands.compactMap { $0.pirateIsland }.filter {
                    let marker = CustomMapMarker(
                        id: UUID(),
                        coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                        title: $0.islandName ?? "",
                        pirateIsland: $0
                    )
                    return marker.distance(from: location) <= self.selectedRadius * 1609.34
                }
            } catch {
                print("Geocoding error: \(error.localizedDescription)")
            }
        }
    }
}

struct EnterZipCodeView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.viewContext
        
        // Initialize the AppDayOfWeekRepository using the shared PersistenceController
        let mockRepository = AppDayOfWeekRepository(persistenceController: PersistenceController.shared)
        
        // Create mock PirateIsland objects
        let mockIsland = PirateIsland(context: context)
        
        let newYorkIsland = PirateIsland(context: context)
        newYorkIsland.latitude = 40.7128
        newYorkIsland.longitude = -74.0060
        newYorkIsland.islandName = "NY Gym"
        newYorkIsland.islandID = UUID()

        let eugeneIsland = PirateIsland(context: context)
        eugeneIsland.latitude = 44.0521
        eugeneIsland.longitude = -123.0868
        eugeneIsland.islandName = "Eugene Gym"
        eugeneIsland.islandID = UUID()
        
        do {
            try context.save()
        } catch {
            print("Failed to save mock data: \(error.localizedDescription)")
        }

        // Initialize EnterZipCodeViewModel with the mock repository and PersistenceController
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(
            repository: mockRepository,
            persistenceController: PersistenceController.shared
        )
        
        // Initialize AppDayOfWeekViewModel with the mock Island
        let mockAppDayOfWeekViewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        
        // Initialize AllEnteredLocationsViewModel with the data manager
        let mockAllEnteredLocationsViewModel = AllEnteredLocationsViewModel(
            dataManager: PirateIslandDataManager(viewContext: context)
        )
        
        return EnterZipCodeView(
            appDayOfWeekViewModel: mockAppDayOfWeekViewModel,
            allEnteredLocationsViewModel: mockAllEnteredLocationsViewModel,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        .environment(\.managedObjectContext, context)
    }
}
