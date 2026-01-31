import SwiftUI
import CoreLocation
import MapKit
import CoreData
import Combine

struct EnterZipCodeView: View {
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @ObservedObject private var userLocationMapViewModel = UserLocationMapViewModel.shared

    @State private var locationInput: String = ""
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    @State private var selectedIsland: PirateIsland? = nil
    @State private var showModal: Bool = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek? = nil
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var navigationPath = NavigationPath()
    @State private var pendingRegion: MKCoordinateRegion? = nil
    @State private var showSearchThisArea = false

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // MARK: - Location Input
                    TextField("Enter Location (Zip Code, Address, City, State)", text: $locationInput)
                        .padding()
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            Task {
                                do {
                                    let coordinate = try await MapUtils.geocodeAddressWithFallback(locationInput)
                                    updateCamera(to: coordinate)

                                    // Update markers immediately
                                    await MainActor.run {
                                        enterZipCodeViewModel.updateMarkersForCenter(
                                            coordinate,
                                            span: cameraPosition.region?.span ?? MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                        )
                                        showSearchThisArea = false
                                    }
                                } catch {
                                    print("Geocoding failed: \(error.localizedDescription)")
                                }
                            }
                        }

                    // MARK: - Map Section
                    mapSection
                        .frame(height: geo.size.height - 70) // fill remaining space
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Enter Location")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("(e.g., Disneyland, Rio De Janeiro, Culinary Institute of America)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .floatingModal(isPresented: $showModal) {
            IslandModalContainer(
                selectedIsland: $selectedIsland,
                viewModel: appDayOfWeekViewModel,
                selectedDay: $selectedDay,
                showModal: $showModal,
                enterZipCodeViewModel: enterZipCodeViewModel,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                navigationPath: $navigationPath
            )
        }
        .onAppear {
            if let userLocation = userLocationMapViewModel.userLocation {
                updateCamera(to: userLocation.coordinate)
            } else {
                requestUserLocation()
            }
        }
        .onChange(of: userLocationMapViewModel.userLocation) { _, newValue in
            if let location = newValue {
                updateCamera(to: location.coordinate)
            }
        }
    }

    // MARK: - Map Section
    private var mapSection: some View {
        ZStack(alignment: .top) {
            IslandMapView(
                viewModel: appDayOfWeekViewModel,
                selectedIsland: $selectedIsland,
                showModal: $showModal,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                selectedDay: $selectedDay,
                allEnteredLocationsViewModel: allEnteredLocationsViewModel,
                enterZipCodeViewModel: enterZipCodeViewModel,
                cameraPosition: $cameraPosition,
                onMapRegionChange: { region in
                    pendingRegion = region
                    showSearchThisArea = true
                }
            )

            if showSearchThisArea {
                searchThisAreaButton
            }
        }
    }

    // MARK: - Helpers
    private func updateCamera(to coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    }

    private func requestUserLocation() {
        userLocationMapViewModel.requestLocation()
    }

    private var searchThisAreaButton: some View {
        Button {
            guard let region = pendingRegion else { return }
            Task {
                await MainActor.run {
                    showSearchThisArea = false
                    enterZipCodeViewModel.updateMarkersForCenter(region.center, span: region.span)
                }
            }
        } label: {
            Text("Search this area")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(22)
                .shadow(radius: 4)
        }
        .padding(.top, 12)
    }
}
