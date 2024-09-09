// DayOfWeekSearchView.swift
// Seas_3
//
// Created by Brian Romero on 8/21/24.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData

struct Gym: Identifiable, Hashable {
    let id: UUID?
    let name: String
    let latitude: Double
    let longitude: Double
    let hasScheduledMatTime: Bool
    let days: [String]

    static func == (lhs: Gym, rhs: Gym) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DayOfWeekSearchView: View {
    @Binding var selectedIsland: PirateIsland?
    @StateObject private var userLocationMapViewModel = UserLocationMapViewModel()
    @State private var gyms: [Gym] = []
    @State private var radius: Double = 10.0
    @State private var equatableRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var errorMessage: String?
    @Binding var selectedGym: Gym?
    @State private var showModal = false
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var selectedDay: DayOfWeek? = .monday
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Binding var region: MKCoordinateRegion
    @Binding var searchResults: [PirateIsland]
    
    var body: some View {
        NavigationView {
            VStack {
                DayPickerView(selectedDay: $selectedDay)
                    .onChange(of: selectedDay) { newDay in
                        print("Selected Day: \(newDay?.displayName ?? "nil")")
                        self.gyms = fetchGyms(day: newDay, radius: radius, locationManager: userLocationMapViewModel)
                        updateRegion(newRadius: radius)
                    }
                
                RadiusPicker(selectedRadius: $radius)
                    .onChange(of: radius) { newRadius in
                        print("Selected Radius: \(newRadius)")
                        updateRegion(newRadius: newRadius)
                        self.gyms = fetchGyms(day: selectedDay, radius: newRadius, locationManager: userLocationMapViewModel)
                    }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else {
                    Map(coordinateRegion: $equatableRegion, annotationItems: gyms) { gym in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: gym.latitude, longitude: gym.longitude)) {
                            Button(action: {
                                print("Toggling showModal")
                                self.selectedGym = gym
                                if let islandID = gym.id {
                                    let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                                    fetchRequest.predicate = NSPredicate(format: "islandID == %@", islandID as CVarArg)
                                    do {
                                        let pirateIslands = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
                                        if let pirateIsland = pirateIslands.first {
                                            self.selectedIsland = pirateIsland
                                        }
                                    } catch {
                                        print("Error fetching PirateIsland: \(error.localizedDescription)")
                                    }
                                }
                                self.showModal = true // Toggle the showModal binding to show the modal
                            }) {
                                VStack {
                                    Text(gym.name)
                                        .font(.caption)
                                        .padding(5)
                                        .background(Color.white)
                                        .cornerRadius(5)
                                        .shadow(radius: 3)
                                    CustomMarkerView() // Use your custom marker view here
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showModal) {
                        VStack {
                            if let selectedGym = selectedGym {
                                IslandModalView(
                                    customMapMarker: nil,
                                    islandName: selectedGym.name,
                                    islandLocation: "\(selectedGym.latitude), \(selectedGym.longitude)",
                                    formattedCoordinates: "",
                                    createdTimestamp: "",
                                    formattedTimestamp: "",
                                    gymWebsite: nil,
                                    reviews: [],
                                    averageStarRating: "",
                                    dayOfWeekData: [],
                                    selectedAppDayOfWeek: .constant(nil),
                                    selectedIsland: .constant(nil),
                                    viewModel: AppDayOfWeekViewModel(
                                        repository: AppDayOfWeekRepository.shared,
                                        enterZipCodeViewModel: enterZipCodeViewModel
                                    ),
                                    selectedDay: $selectedDay,
                                    showModal: $showModal, // Pass showModal
                                    enterZipCodeViewModel: enterZipCodeViewModel // Pass enterZipCodeViewModel
                                )
                            } else {
                                Text("No Gym Selected")
                                    .padding()
                            }
                        }
                    }
                }
            }
            .onAppear {
                userLocationMapViewModel.requestLocation()
                DispatchQueue.main.async {
                    self.equatableRegion = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                }
            }
            .onChange(of: userLocationMapViewModel.userLocation) { newLocation in
                if let location = newLocation {
                    equatableRegion = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                    self.gyms = fetchGyms(day: selectedDay, radius: radius, locationManager: userLocationMapViewModel)
                    print("Fetched \(self.gyms.count) gyms")
                }
            }
        }
    }
    
    func fetchGyms(day: DayOfWeek?, radius: Double, locationManager: UserLocationMapViewModel) -> [Gym] {
        guard let day = day else {
            print("Day is nil")
            return []
        }
        
        var fetchedGyms: [Gym] = []
        
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day ==[c] %@", day.rawValue)
        fetchRequest.relationshipKeyPathsForPrefetching = ["pIsland", "matTimes"]
        
        do {
            let appDayOfWeeks = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            print("Fetched \(appDayOfWeeks.count) AppDayOfWeek objects")
            
            for appDayOfWeek in appDayOfWeeks {
                guard let island = appDayOfWeek.pIsland else { continue }
                guard let appDay = appDayOfWeek.day, appDay.lowercased() == day.displayName.lowercased() else { continue }
                guard appDayOfWeek.matTimes?.count ?? 0 > 0 else { continue }
                
                let distance = locationManager.userLocation.map {
                    locationManager.calculateDistance(from: $0, to: CLLocation(latitude: island.latitude, longitude: island.longitude))
                } ?? 0
                print("Distance to Island: \(distance)")
                
                fetchedGyms.append(
                    Gym(
                        id: island.islandID ?? UUID(),
                        name: island.islandName ?? "Unnamed Gym",
                        latitude: island.latitude,
                        longitude: island.longitude,
                        hasScheduledMatTime: true,
                        days: [appDayOfWeek.day ?? "Unknown Day"]
                    )
                )
            }
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error.localizedDescription)")
            errorMessage = "Error fetching gyms: \(error.localizedDescription)"
        }
        
        print("Fetched \(fetchedGyms.count) gyms")
        return fetchedGyms
    }
    
    private func updateRegion(newRadius: Double) {
        if let location = userLocationMapViewModel.userLocation {
            withAnimation {
                equatableRegion = MapUtils.updateRegion(
                    markers: gyms.map { CustomMapMarker(
                        id: $0.id ?? UUID(),
                        coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                        title: $0.name,
                        pirateIsland: nil
                    ) },
                    selectedRadius: newRadius,
                    center: location.coordinate
                )
            }
        } else {
            print("User location is nil")
            errorMessage = "Error updating region: User location is nil"

        }
    }
}

struct DayOfWeekSearchView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let viewContext = persistenceController.container.viewContext
        
        // Create sample data
        createSampleData(viewContext: viewContext)
 
        return Group {
            DayOfWeekSearchView(
                selectedIsland: .constant(nil),
                selectedGym: .constant(nil),
                viewModel: AppDayOfWeekViewModel(
                    selectedIsland: nil,
                    repository: AppDayOfWeekRepository.shared,
                    enterZipCodeViewModel: EnterZipCodeViewModel(
                        repository: AppDayOfWeekRepository.shared,
                        context: viewContext
                    )
                ),
                selectedAppDayOfWeek: .constant(nil),
                allEnteredLocationsViewModel: AllEnteredLocationsViewModel(
                    dataManager: PirateIslandDataManager(
                        viewContext: viewContext
                    )
                ),
                enterZipCodeViewModel: EnterZipCodeViewModel(
                    repository: AppDayOfWeekRepository.shared,
                    context: viewContext
                ),
                region: .constant(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                ),
                searchResults: .constant([])
            )
        }
    }
    
    private static func createSampleData(viewContext: NSManagedObjectContext) {
        // Clear existing data
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PirateIsland.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try viewContext.execute(deleteRequest)
        } catch {
            print("Error clearing existing PirateIsland data: \(error.localizedDescription)")
        }
        
        // Create new data
        let island1 = PirateIsland(context: viewContext)
        island1.islandID = UUID()
        island1.islandLocation = "Los Angeles, CA"
        island1.islandName = "LA Gym"
        island1.latitude = 34.0522
        island1.longitude = -118.2437

        let island2 = PirateIsland(context: viewContext)
        island2.islandID = UUID()
        island2.islandLocation = "Los Angeles, CA"
        island2.islandName = "Hollywood Gym"
        island2.latitude = 34.1016
        island2.longitude = -118.3402

        let island3 = PirateIsland(context: viewContext)
        island3.islandID = UUID()
        island3.islandLocation = "Los Angeles, CA"
        island3.islandName = "Downtown Gym"
        island3.latitude = 34.0522
        island3.longitude = -118.2437

        // Create AppDayOfWeek
        let appDayOfWeek1 = AppDayOfWeek(context: viewContext)
        appDayOfWeek1.day = "Monday"
        appDayOfWeek1.pIsland = island1
        appDayOfWeek1.matTimes = NSSet(array: [
            MatTime(context: viewContext),
            MatTime(context: viewContext)
        ])

        let appDayOfWeek2 = AppDayOfWeek(context: viewContext)
        appDayOfWeek2.day = "Wednesday"
        appDayOfWeek2.pIsland = island2
        appDayOfWeek2.matTimes = NSSet(array: [
            MatTime(context: viewContext),
            MatTime(context: viewContext)
        ])

        let appDayOfWeek3 = AppDayOfWeek(context: viewContext)
        appDayOfWeek3.day = "Friday"
        appDayOfWeek3.pIsland = island3
        appDayOfWeek3.matTimes = NSSet(array: [
            MatTime(context: viewContext),
            MatTime(context: viewContext)
        ])
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving preview data: \(error.localizedDescription)")
        }
    }
}
