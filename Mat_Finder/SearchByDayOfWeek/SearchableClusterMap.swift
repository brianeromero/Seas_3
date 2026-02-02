//
//  SearchableClusterMap.swift
//  Mat_Finder
//
//  Created by Brian Romero on 2/1/26.
//

import SwiftUI
import MapKit

struct SearchableClusterMap: View {
    @Binding var region: MKCoordinateRegion
    let markers: [CustomMapMarker]

    let onRegionSearchRequested: (MKCoordinateRegion) -> Void
    let onMarkerTap: (CustomMapMarker) -> Void

    @State private var mapUpdateTask: Task<Void, Never>?

    var body: some View {
        Map(position: mapCameraBinding) {
            ForEach(markers) { marker in
                Annotation("", coordinate: marker.coordinate, anchor: .center) {
                    if marker.pirateIsland != nil {
                        AnnotationMarkerView(island: marker.pirateIsland!) {_ in 
                            onMarkerTap(marker)  // <-- use the closure passed in
                        }
                    } else {
                        ClusterMarkerView(count: marker.count ?? 0)
                            .onTapGesture { zoomIntoCluster(marker) }
                    }
                }
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            mapUpdateTask?.cancel()
            mapUpdateTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !Task.isCancelled {
                    onRegionSearchRequested(context.region)
                }
            }
        }
    }

    private var mapCameraBinding: Binding<MapCameraPosition> {
        Binding(
            get: { .region(region) },
            set: { if let r = $0.region { region = r } }
        )
    }

    private func zoomIntoCluster(_ marker: CustomMapMarker) {
        let newSpan = MKCoordinateSpan(
            latitudeDelta: max(region.span.latitudeDelta * 0.5, 0.005),
            longitudeDelta: max(region.span.longitudeDelta * 0.5, 0.005)
        )

        region = MKCoordinateRegion(
            center: marker.coordinate,
            span: newSpan
        )
    }
}
