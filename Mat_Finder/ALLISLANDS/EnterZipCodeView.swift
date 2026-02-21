import SwiftUI
import CoreLocation
import MapKit
import CoreData
import Combine


struct EnterZipCodeView: View {

    // MARK: - Dependencies
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @ObservedObject private var userLocationMapViewModel = UserLocationMapViewModel.shared

    // MARK: - State
    @State private var locationInput: String = ""
    @State private var selectedIsland: PirateIsland?
    @State private var showModal = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var navigationPath = NavigationPath()
    @State private var pendingRegion: MKCoordinateRegion?
    @State private var showSearchThisArea = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // MARK: - Location Input
                TextField(
                    "Enter Location (Zip Code, Address, City, State)",
                    text: $locationInput
                )
                .padding()
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .onSubmit {
                    Task {
                        do {
                            let coordinate = try await MapUtils.geocodeAddressWithFallback(locationInput)
                            updateCamera(to: coordinate)

                            await MainActor.run {
                                enterZipCodeViewModel.userDidMoveMap(
                                    to: MKCoordinateRegion(
                                        center: coordinate,
                                        span: enterZipCodeViewModel.region.span
                                    )
                                )
                                showSearchThisArea = false
                            }
                        } catch {
                            print("Geocoding failed: \(error.localizedDescription)")
                        }
                    }
                }

                // MARK: - Map
                mapSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .onChange(of: userLocationMapViewModel.userLocation) { oldValue, newValue in
            if let location = newValue {
                updateCamera(to: location.coordinate)
            }
        }

    }

    // MARK: - Map Section
    private var mapSection: some View {

        ZStack(alignment: .top) {

            IslandMKMapView(
                islands: enterZipCodeViewModel.pirateIslands,
                selectedIsland: $selectedIsland,
                showModal: $showModal,
                region: enterZipCodeViewModel.region
            )
            .id(enterZipCodeViewModel.pirateIslands.map(\.objectID))


            if showSearchThisArea {

                searchThisAreaButton
            }
        }
    }



    // MARK: - Helpers
    private func updateCamera(to coordinate: CLLocationCoordinate2D) {
        enterZipCodeViewModel.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }


    private func requestUserLocation() {
        userLocationMapViewModel.requestLocation()
    }

    private var searchThisAreaButton: some View {
        Button {
            guard let region = pendingRegion else { return }

            showSearchThisArea = false

            enterZipCodeViewModel.userDidMoveMap(to: region)
        } label: {
            Text("Search this Area")
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
