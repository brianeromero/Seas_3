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

        VStack {

            if favoriteIslands.isEmpty {

                Text("No Favorites Yet")
                    .font(.headline)
                    .foregroundColor(.secondary)

            } else {

                IslandMKMapView(
                    islands: favoriteIslands,
                    selectedIsland: $selectedIsland,
                    showModal: $showModal,
                    region: cameraPosition.region ?? defaultRegion
                )
                .overlay(alignment: .topTrailing) {

                    // Fit All Favorites Button
                    Button {

                        withAnimation {
                            cameraPosition = .region(regionToFitFavorites())
                        }

                    } label: {

                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 20))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
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

            if !favoriteIslands.isEmpty {

                DispatchQueue.main.async {

                    withAnimation {
                        cameraPosition = .region(regionToFitFavorites())
                    }

                }
            }
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
    private func regionToFitFavorites() -> MKCoordinateRegion {

        let coordinates = favoriteIslands.map {
            CLLocationCoordinate2D(
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }

        guard !coordinates.isEmpty else { return defaultRegion }

        let minLat = coordinates.map { $0.latitude }.min()!
        let maxLat = coordinates.map { $0.latitude }.max()!
        let minLon = coordinates.map { $0.longitude }.min()!
        let maxLon = coordinates.map { $0.longitude }.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.05)
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}
