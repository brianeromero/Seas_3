//
//  DayOfWeekSearchView.swift
//  Seas_3
//
//  Created by Brian Romero on 8/21/24.
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
    @StateObject private var userLocationMapViewModel = UserLocationMapViewModel()
    @State private var gyms: [Gym] = []
    @State private var selectedDay: String = "Monday"
    @State private var isLoading: Bool = false
    @State private var radius: Double = 10.0 // Example initial radius value
    @State private var equatableRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        VStack {
            Picker("Select Day", selection: $selectedDay) {
                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], id: \.self) { day in
                    Text(day).tag(day)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Text("Radius: \(Int(radius * 1.60934)) miles")
                .padding(.bottom, 5)

            Slider(value: $radius, in: 1...50, step: 1)
                .padding()

            if isLoading {
                ProgressView()
            } else {
                Map(coordinateRegion: $equatableRegion, annotationItems: gyms) { gym in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: gym.latitude, longitude: gym.longitude)) {
                        VStack {
                            Text(gym.name)
                                .font(.caption)
                                .padding(5)
                                .background(Color.white)
                                .cornerRadius(5)
                                .shadow(radius: 3)
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .edgesIgnoringSafeArea(.all)
            }
        }

        .onAppear {
            userLocationMapViewModel.requestLocation()
            fetchGyms(day: selectedDay, radius: radius)
        }
        .onChange(of: radius) { newRadius in
            fetchGyms(day: selectedDay, radius: newRadius)
            updateRegion(newRadius: newRadius)
        }
        .onChange(of: selectedDay) { newDay in
            fetchGyms(day: newDay, radius: radius)
        }
    }

    private func fetchGyms(day: String, radius: Double) {
        let radiusInKilometers = radius * 1.60934 // Convert miles to kilometers

        guard !isLoading else { return }
        isLoading = true

        Task {
            let normalizedDay = day.lowercased()
            let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "day BEGINSWITH[c] %@", normalizedDay)
            fetchRequest.relationshipKeyPathsForPrefetching = ["pIsland"]

            do {
                let appDayOfWeeks = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)

                var fetchedGyms: [Gym] = []

                for appDayOfWeek in appDayOfWeeks {
                    guard let island = appDayOfWeek.pIsland else { continue }

                    let hasScheduledMatTime = appDayOfWeek.matTimes?.count ?? 0 > 0
                    fetchedGyms.append(
                        Gym(
                            id: island.islandID ?? UUID(),
                            name: island.islandName,
                            latitude: island.latitude,
                            longitude: island.longitude,
                            hasScheduledMatTime: hasScheduledMatTime,
                            days: [appDayOfWeek.day ?? ""]
                        )
                    )
                }

                DispatchQueue.main.async {
                    self.gyms = fetchedGyms
                    self.isLoading = false
                }
            } catch {
                print("Failed to fetch AppDayOfWeek: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    private func updateRegion(newRadius: Double) {
        let newRadiusInKilometers = newRadius * 1.60934 // Convert miles to kilometers

        guard let userLocation = userLocationMapViewModel.getCurrentUserLocation() else { return }
        let latitudeDelta = newRadiusInKilometers / 111.0
        let longitudeDelta = newRadiusInKilometers / (111.0 * cos(userLocation.coordinate.latitude * .pi / 180))
        equatableRegion = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

struct DayOfWeekSearchView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DayOfWeekSearchView()
                .previewDisplayName("Default Preview")
                .environment(\.colorScheme, .light)
            
            DayOfWeekSearchView()
                .previewDisplayName("Dark Mode Preview")
                .environment(\.colorScheme, .dark)
        }
    }
}
