//
//  CustomMarkerView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//
import Foundation
import SwiftUI
import MapKit // Crucial for Map views

// MARK: - CustomMarkerView
struct CustomMarkerView: View {
    var body: some View {
        Image(systemName: "mappin.circle.fill") // Your marker content
            .foregroundColor(.blue) // The color of your marker
    }
}


// MARK: - CustomMarkerView Standalone Preview
struct CustomMarkerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomMarkerView()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.white) // For better visibility in the preview pane
            .previewDisplayName("Custom Marker Standalone Preview")
    }
}



// MARK: - Custom Map Preview with Marker
struct CustomMapMarkerPreview: View {
    // This is a simple mock island for the preview.
    // In your actual app, 'PirateIsland' would come from your data models.
    let previewIsland = MockPirateIsland.example

    // @State is needed for MapCameraPosition in a preview
    @State private var cameraPosition: MapCameraPosition = {
        let coordinate = CLLocationCoordinate2D(latitude: MockPirateIsland.example.latitude, longitude: MockPirateIsland.example.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        return .region(MKCoordinateRegion(center: coordinate, span: span))
    }()

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                // Annotate the map with your custom marker
                Annotation(previewIsland.islandName ?? "Preview Island", coordinate: CLLocationCoordinate2D(latitude: previewIsland.latitude, longitude: previewIsland.longitude), anchor: .center) {
                    // This VStack combines the island name text and your CustomMarkerView
                    VStack {
                        Text(previewIsland.islandName ?? "Unnamed Island")
                            .font(.caption)
                            .padding(5)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(5)
                        CustomMarkerView() // Your actual custom marker view
                    }
                    .onTapGesture {
                        print("Tapped on preview island: \(previewIsland.islandName ?? "Unnamed")")
                    }
                }
            }
            .mapControls {
                // Add default map controls for better preview interaction
                MapUserLocationButton()
                MapCompass()
            }
        }
        .frame(width: 350, height: 400) // Define a fixed size for the preview canvas
        .previewDisplayName("Map with Custom Marker")
    }
}


// MARK: - Preview Provider for the Map Preview
struct CustomMapMarkerPreview_Previews: PreviewProvider {
    static var previews: some View {
        CustomMapMarkerPreview()
    }
}



// MARK: - Mock Data for Preview
// You'll need to ensure your 'PirateIsland' type is defined elsewhere in your project.
// This 'MockPirateIsland' struct serves as a stand-in for preview purposes.
struct MockPirateIsland: Identifiable {
    let id = UUID()
    var islandName: String? = "Your Mom's Gym"
    var latitude: Double = 34.0522 // Example: Los Angeles latitude
    var longitude: Double = -118.2437 // Example: Los Angeles longitude

    static let example = MockPirateIsland()
}
