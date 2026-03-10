// AllIslandMapView.swift
// Mat_Finder
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit
import os
import OSLog



// Default region for initialization
private let defaultRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
)

struct ConsolidatedIslandMapView: View {

    @Environment(\.managedObjectContext)
    private var viewContext

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: []
    )
    private var islands: FetchedResults<PirateIsland>

    @ObservedObject
    var enterZipCodeViewModel: EnterZipCodeViewModel


    @StateObject
    private var viewModel: AppDayOfWeekViewModel


    @ObservedObject
    private var locationManager: UserLocationMapViewModel


    @State
    private var selectedRadius: Double = 5.0


    @State
    private var cameraPosition: MapCameraPosition =
        .region(defaultRegion)


    @State
    private var showModal = false


    @State
    private var selectedIsland: PirateIsland?


    @State
    private var selectedAppDayOfWeek: AppDayOfWeek?


    @State
    private var selectedDay: DayOfWeek? = .monday


    @Binding
    var navigationPath: NavigationPath

    @State private var showIslandList = false


    // MARK: Init

    init(
        viewModel: AppDayOfWeekViewModel,
        enterZipCodeViewModel: EnterZipCodeViewModel,
        navigationPath: Binding<NavigationPath>
    ) {

        _viewModel =
            StateObject(wrappedValue: viewModel)

        self.enterZipCodeViewModel =
            enterZipCodeViewModel

        _locationManager =
            ObservedObject(
                wrappedValue:
                    UserLocationMapViewModel.shared
            )

        _navigationPath =
            navigationPath
    }



    // MARK: Body

    var body: some View {

        VStack {

            if locationManager.userLocation != nil {

                ZStack {

                    makeMapView()

                    MapControlsView(

                        fitAction: {

                            guard
                                let mapView = IslandMKMapView.sharedMapView,
                                let userLocation = locationManager.userLocation
                            else { return }

                            let radiusMeters = selectedRadius * 1609.34

                            let nearbyAnnotations = mapView.annotations.compactMap { annotation -> IslandAnnotation? in
                                guard let islandAnnotation = annotation as? IslandAnnotation else { return nil }

                                let islandLocation = CLLocation(
                                    latitude: islandAnnotation.coordinate.latitude,
                                    longitude: islandAnnotation.coordinate.longitude
                                )

                                return islandLocation.distance(from: userLocation) <= radiusMeters
                                    ? islandAnnotation
                                    : nil
                            }

                            guard !nearbyAnnotations.isEmpty else { return }

                            if nearbyAnnotations.count == 1,
                               let coord = nearbyAnnotations.first?.coordinate {

                                let region = MKCoordinateRegion(
                                    center: coord,
                                    latitudinalMeters: radiusMeters,
                                    longitudinalMeters: radiusMeters
                                )

                                mapView.setRegion(region, animated: true)

                            } else {

                                mapView.showAnnotations(nearbyAnnotations, animated: true)

                            }
                        },

                        listAction: {
                            showIslandList = true
                        },

                        userLocationVM: locationManager
                    )
                }

                makeRadiusPicker()
            } else {

                ProgressView("Fetching user location…")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }

        .navigationBarTitleDisplayMode(.inline)

        .toolbar {

            ToolbarItem(placement: .principal) {

                Text("Gyms Near Me")
                    .font(.title)
                    .fontWeight(.bold)
            }
        }

        .overlay(overlayContentView())

        .onAppear {

            onAppear()
        }

        .onChange(of: locationManager.userLocation) {

            _, newValue in

            onChangeUserLocation(newValue)
        }

        .onChange(of: selectedRadius) {

            _, newValue in

            onChangeSelectedRadius(newValue)
        }
        
        .sheet(isPresented: $showIslandList) {

            DayOfWeekIslandListView(

                islands: Array(islands),

                userLocation: locationManager.userLocation

            ) { island in

                selectedIsland = island
                showModal = true
                showIslandList = false

                zoomToIsland(island)
            }
        }
    }

    
    private func zoomToIsland(_ island: PirateIsland) {

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
    }


    // MARK: Map View
    private func makeMapView() -> some View {

        IslandMKMapView(
            islands: Array(islands),
            selectedIsland: $selectedIsland,
            showModal: $showModal,
            selectedRadius: selectedRadius,
            region: cameraPosition.region ?? defaultRegion
        )
        
    }


    // MARK: Radius Picker

    private func makeRadiusPicker() -> some View {

        RadiusPicker(
            selectedRadius: $selectedRadius
        )

        .padding()
    }



    // MARK: Overlay

    private func overlayContentView() -> some View {

        ZStack {

            if showModal {

                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                    .onTapGesture {
                        showModal = false
                        selectedIsland = nil
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

                    .frame(
                        maxWidth: 600,
                        maxHeight: 600
                    )

                    .background(Color(.systemBackground))

                    .cornerRadius(12)

                    .padding()
                }
            }
        }

        .animation(
            .easeInOut,
            value: showModal
        )
    }



    // MARK: Location Handling

    private func onAppear() {

        if locationManager.userLocation == nil {

            locationManager.startLocationServices()

        } else if let location =
                    locationManager.userLocation {

            updateRegion(
                location,
                radius: selectedRadius
            )
        }

        // ⭐ Auto-open list if too many gyms
        if islands.count > 40 && selectedRadius >= 25 {
            showIslandList = true
        }
    }


    private func onChangeUserLocation(
        _ location: CLLocation?
    ) {

        guard let location else { return }


        updateRegion(
            location,
            radius: selectedRadius
        )
    }



    private func onChangeSelectedRadius(
        _ radius: Double
    ) {

        guard let center =
            cameraPosition.region?.center
        else { return }


        let region =
            MKCoordinateRegion(
                center: center,
                latitudinalMeters:
                    radius * 1609.34,
                longitudinalMeters:
                    radius * 1609.34
            )


        cameraPosition =
            .region(region)
    }



    private func updateRegion(
        _ location: CLLocation,
        radius: Double
    ) {

        let region =
            MKCoordinateRegion(

                center:
                    location.coordinate,

                latitudinalMeters:
                    radius * 1609.34,

                longitudinalMeters:
                    radius * 1609.34
            )


        cameraPosition =
            .region(region)
    }

}

// MARK: - MKMapView Wrapper with Clustering

struct IslandMKMapView: UIViewRepresentable {

    var islands: [PirateIsland]

    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool
    
    var selectedRadius: Double     // ✅ ADD THIS


    var region: MKCoordinateRegion

    var onRegionChanged: ((MKCoordinateRegion) -> Void)?   // ✅ ADD THIS
    static var sharedMapView: MKMapView?

    func makeUIView(context: Context) -> MKMapView {

        let mapView = MKMapView()
        
        IslandMKMapView.sharedMapView = mapView

        mapView.delegate = context.coordinator

        mapView.setRegion(region, animated: false)

        mapView.showsUserLocation = true

        mapView.pointOfInterestFilter = .excludingAll

        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: "marker"
        )
        
        mapView.preferredConfiguration = MKStandardMapConfiguration()
        
        // ✅ ADD THIS LINE HERE
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false

        return mapView
    }


    func updateUIView(_ mapView: MKMapView, context: Context) {

        if !showModal {
            context.coordinator.deselectAllAnnotations(mapView)
        }

        let islandIDs = Set(
            islands.map {
                $0.islandID ?? $0.objectID.uriRepresentation().absoluteString
            }
        )

        if islandIDs != context.coordinator.lastIslandIDs {

            context.coordinator.updateAnnotations(
                on: mapView,
                with: islands
            )

            context.coordinator.lastIslandIDs = islandIDs
        }

        if !context.coordinator.isSameRegion(region) {

            MapUtils.setMapRegion(
                mapView: mapView,
                centerCoordinate: region.center,
                span: region.span
            )

            context.coordinator.lastRegion = region
        }
    }
    
    func makeCoordinator() -> Coordinator {

        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: IslandMKMapView
        var currentAnnotations: [String: IslandAnnotation] = [:]
        var lastRegion: MKCoordinateRegion?
        var lastIslandIDs: Set<String> = []   // ✅ ADD THIS

        init(_ parent: IslandMKMapView) {
            self.parent = parent
        }

        // ✅ ADD HERE
        func deselectAllAnnotations(_ mapView: MKMapView) {
            for annotation in mapView.selectedAnnotations {
                mapView.deselectAnnotation(annotation, animated: true)
            }
        }


        // ✅ MOVE THIS FUNCTION HERE
        func isSameRegion(_ newRegion: MKCoordinateRegion) -> Bool {

            guard let lastRegion else { return false }

            let epsilon = 0.00001
            return

                abs(lastRegion.center.latitude - newRegion.center.latitude) < epsilon &&

                abs(lastRegion.center.longitude - newRegion.center.longitude) < epsilon &&

                abs(lastRegion.span.latitudeDelta - newRegion.span.latitudeDelta) < epsilon &&

                abs(lastRegion.span.longitudeDelta - newRegion.span.longitudeDelta) < epsilon
        }


        func updateAnnotations(
            on mapView: MKMapView,
            with islands: [PirateIsland]
        ) {

            // NEW set
            var newAnnotations: [String: IslandAnnotation] = [:]

            for island in islands {

                guard let id = island.islandID else { continue }

                if let existing = currentAnnotations[id] {

                    // reuse existing annotation
                    newAnnotations[id] = existing

                } else {

                    // create new annotation
                    let annotation = IslandAnnotation(island: island)

                    newAnnotations[id] = annotation

                    mapView.addAnnotation(annotation)
                }
            }


            // REMOVE annotations no longer valid (batch removal)
            let annotationsToRemove = currentAnnotations
                .filter { newAnnotations[$0.key] == nil }
                .map { $0.value }

            mapView.removeAnnotations(annotationsToRemove)


            // save new state
            currentAnnotations = newAnnotations
        }

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {

            if annotation is MKUserLocation {

                return nil
            }


            guard let annotation = annotation as? IslandAnnotation
            else { return nil }


            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: "marker",
                for: annotation
            ) as! MKMarkerAnnotationView


            view.markerTintColor = .systemRed
            view.clusteringIdentifier = "gym"
            view.displayPriority = .defaultHigh
            view.animatesWhenAdded = true
            view.collisionMode = .circle

            return view
        }


        func mapView(
            _ mapView: MKMapView,
            didSelect view: MKAnnotationView
        ) {

            // Prevent user location from showing the avatar callout
            if view.annotation is MKUserLocation {

                if let userLocation = mapView.userLocation.location {

                    let meters = parent.selectedRadius * 1609.34

                    let region = MKCoordinateRegion(
                        center: userLocation.coordinate,
                        latitudinalMeters: meters,
                        longitudinalMeters: meters
                    )

                    mapView.setRegion(region, animated: true)
                }

                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }

            if let cluster = view.annotation as? MKClusterAnnotation {

                let region = MKCoordinateRegion(
                    center: cluster.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: mapView.region.span.latitudeDelta / 2,
                        longitudeDelta: mapView.region.span.longitudeDelta / 2
                    )
                )

                mapView.setRegion(region, animated: true)
                return
            }

            guard let annotation = view.annotation as? IslandAnnotation else { return }

            parent.selectedIsland = annotation.island
            parent.showModal = true
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {

            parent.onRegionChanged?(mapView.region)

            NotificationCenter.default.post(
                name: .mapRegionDidChange,
                object: nil
            )
        }
        
    }
    
    
}




class IslandAnnotation: NSObject, MKAnnotation {

    let island: PirateIsland
    var coordinate: CLLocationCoordinate2D
    var title: String?
    init(island: PirateIsland) {

        self.island = island
        self.coordinate =
            CLLocationCoordinate2D(
                latitude: island.latitude,
                longitude: island.longitude
            )

        self.title = island.islandName

        super.init()
    }
}
