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

        ZStack {

            // Map
            IslandMKMapView(
                islands: enterZipCodeViewModel.pirateIslands,
                selectedIsland: $selectedIsland,
                showModal: $showModal,
                region: enterZipCodeViewModel.region,
                onRegionChanged: { newRegion in

                    let epsilon = 0.0001

                    let latDiff =
                    abs(newRegion.center.latitude -
                        enterZipCodeViewModel.region.center.latitude)

                    let lonDiff =
                    abs(newRegion.center.longitude -
                        enterZipCodeViewModel.region.center.longitude)

                    if latDiff > epsilon || lonDiff > epsilon {

                        pendingRegion = newRegion
                        showSearchThisArea = true
                    }
                }
            )
            .id(enterZipCodeViewModel.pirateIslands.map(\.objectID))


            // Floating Apple-style button
            VStack {

                if showSearchThisArea {

                    searchThisAreaButton
                        .transition(
                            .move(edge: .top)
                            .combined(with: .opacity)
                        )
                }

                Spacer()
            }
            .padding(.top, 12)
        }
        .animation(.easeInOut(duration: 0.25), value: showSearchThisArea)
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
                .padding(.horizontal, 18)
                .padding(.vertical, 10)

                // ✅ CHANGE STARTS HERE
                .background(.ultraThinMaterial)

                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )

                .clipShape(Capsule())

                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                // ✅ CHANGE ENDS HERE
        }

        .padding(.top, 12)
    }
}
