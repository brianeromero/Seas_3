import SwiftUI
import CoreData
import MapKit


// ✅ Global default region
private let defaultRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(
        latitude: 37.7749,
        longitude: -122.4194
    ),
    span: MKCoordinateSpan(
        latitudeDelta: 0.5,
        longitudeDelta: 0.5
    )
)

struct FavoritesMap: View {
    @Environment(\.managedObjectContext)
    private var viewContext

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: []
    )
    private var islands: FetchedResults<PirateIsland>

    @ObservedObject private var favoriteManager = FavoriteManager.shared
    @ObservedObject private var userLocationVM = UserLocationMapViewModel.shared

    @State private var selectedIsland: PirateIsland?
    @State private var showModal = false

    @State private var cameraPosition: MapCameraPosition =
        .region(defaultRegion)

    @Binding var navigationPath: NavigationPath

    @ObservedObject
    var enterZipCodeViewModel: EnterZipCodeViewModel

    @StateObject
    private var viewModel: AppDayOfWeekViewModel

    @State
    private var selectedAppDayOfWeek: AppDayOfWeek?

    @State
    private var selectedDay: DayOfWeek? = .monday

    @State private var showFavoritesList = false

    // MARK: Init
    init(
        viewModel: AppDayOfWeekViewModel,
        enterZipCodeViewModel: EnterZipCodeViewModel,
        navigationPath: Binding<NavigationPath>
    ) {

        _viewModel = StateObject(wrappedValue: viewModel)
        self.enterZipCodeViewModel = enterZipCodeViewModel
        _navigationPath = navigationPath
    }


    // MARK: Favorites Filter
    private var favoriteIslands: [PirateIsland] {

        islands.filter {
            guard let id = $0.islandID else { return false }
            return favoriteManager.favoriteIslandIDs.contains(id)
        }
    }


    // MARK: Body
    var body: some View {
        
        let favorites = favoriteIslands
        
        VStack {
            
            if favorites.isEmpty {
                
                Text("No Favorites Yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
            } else {
                
                ZStack {
                    
                    IslandMKMapView(
                        islands: favorites,
                        selectedIsland: $selectedIsland,
                        showModal: $showModal,
                        selectedRadius: 5.0,
                        region: cameraPosition.region ?? defaultRegion
                    )
                    
                    MapControlsView(
                        
                        fitAction: {
                            
                            guard let mapView = IslandMKMapView.sharedMapView else { return }
                            
                            let region = regionToFitFavorites(favorites)
                            
                            mapView.setRegion(region, animated: true)
                            
                            mapView.setVisibleMapRect(
                                mapView.visibleMapRect,
                                edgePadding: UIEdgeInsets(
                                    top: 120,
                                    left: 80,
                                    bottom: 120,
                                    right: 80
                                ),
                                animated: true
                            )
                        },
                        
                        listAction: {
                            showFavoritesList = true
                        },
                        
                        userLocationVM: userLocationVM
                    )
                }
            }
        }
        
        
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {

            ToolbarItem(placement: .principal) {

                Text("Favorites")
                    .font(.title)
                    .fontWeight(.bold)
            }
        }

        .overlay(overlayContentView())

        // Smooth auto zoom when screen appears
        .onAppear {

            // Start map near user
            if let location = userLocationVM.userLocation {

                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 50000,
                    longitudinalMeters: 50000
                )

                cameraPosition = .region(region)
            }

            // ⭐ If only one favorite, zoom directly to it
            if favorites.count == 1,
               let island = favorites.first {

                zoomToIsland(island, showDetails: false)
            }

            // Show list if favorites are global
            let region = regionToFitFavorites(favorites)
            
            if region.span.longitudeDelta > 60 {
                showFavoritesList = true
            }
        }
        
        .sheet(isPresented: $showFavoritesList) {

            FavoritesListView(
                islands: favorites
            ) { island in

                zoomToIsland(island)
                showFavoritesList = false
            }
            .presentationDetents([.medium])
        }
    }


    // MARK: Modal
    private func overlayContentView() -> some View {

        ZStack {

            if showModal {

                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showModal = false
                        selectedIsland = nil   // ✅ ADD THIS
                    }

                if selectedIsland != nil {

                    IslandModalContainer(

                        selectedIsland:
                            $selectedIsland,

                        viewModel:
                            viewModel,

                        selectedDay:
                            $selectedDay,

                        showModal:
                            $showModal,

                        enterZipCodeViewModel:
                            enterZipCodeViewModel,

                        selectedAppDayOfWeek:
                            $selectedAppDayOfWeek,

                        navigationPath:
                            $navigationPath
                    )

                    .frame(maxWidth: 600, maxHeight: 600)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .animation(.easeInOut, value: showModal)
    }


    // MARK: Calculate Map Region
    private func regionToFitFavorites(_ islands: [PirateIsland]) -> MKCoordinateRegion {

        let coordinates = islands.map {
            CLLocationCoordinate2D(
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }

        guard !coordinates.isEmpty else { return defaultRegion }

        guard
            let minLat = coordinates.map({ $0.latitude }).min(),
            let maxLat = coordinates.map({ $0.latitude }).max(),
            let minLon = coordinates.map({ $0.longitude }).min(),
            let maxLon = coordinates.map({ $0.longitude }).max()
        else { return defaultRegion }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: min(max((maxLat - minLat) * 1.5, 0.05), 180),
            longitudeDelta: min(max((maxLon - minLon) * 1.5, 0.05), 180)
        )

        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func zoomToIsland(_ island: PirateIsland, showDetails: Bool = true) {

        guard let mapView = IslandMKMapView.sharedMapView else { return }

        let coordinate = CLLocationCoordinate2D(
            latitude: island.latitude,
            longitude: island.longitude
        )

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 8000,
            longitudinalMeters: 8000
        )

        mapView.setRegion(region, animated: true)

        if showDetails {
            selectedIsland = island
            showModal = true
        }
    }
}


struct FavoritesListView: View {

    let islands: [PirateIsland]
    let onSelect: (PirateIsland) -> Void

    private var groupedIslands: [String: [PirateIsland]] {
        Dictionary(grouping: islands) { island in
            island.country ?? "Other"
        }
    }

    private var sortedCountries: [String] {
        groupedIslands.keys.sorted()
    }

    private func islands(for country: String) -> [PirateIsland] {
        (groupedIslands[country] ?? [])
            .sorted { ($0.islandName ?? "") < ($1.islandName ?? "") }
    }

    var body: some View {

        NavigationStack {

            List {

                ForEach(sortedCountries, id: \.self) { country in

                    Section(header: Text(country).font(.headline)) {

                        ForEach(islands(for: country), id: \.objectID) { island in

                            Button {

                                onSelect(island)

                            } label: {

                                IslandListItem(
                                    island: island,
                                    selectedIsland: .constant(nil)
                                )
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color(.systemBackground))
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Favorites")
        }
    }
}
