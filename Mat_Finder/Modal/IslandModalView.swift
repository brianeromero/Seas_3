//
//  IslandModalView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 8/29/24.
//

import Foundation
import SwiftUI
import CoreLocation

struct IslandModalView: View {
    
    @Environment(\.managedObjectContext) var viewContext
    @Binding var selectedDay: DayOfWeek?
    @Binding var showModal: Bool
    @State private var isLoadingData: Bool = false
    
    @State private var currentAverageStarRating: Double = 0.0
    @State private var currentReviews: [Review] = []
    
    @Binding var navigationPath: NavigationPath
    @State private var showNoScheduleAlert = false
    
    let customMapMarker: CustomMapMarker?
    @State private var scheduleExists: Bool = false
    
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    
    @ObservedObject private var favoriteManager = FavoriteManager.shared
    
    init(
        customMapMarker: CustomMapMarker?,
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>,
        viewModel: AppDayOfWeekViewModel,
        selectedDay: Binding<DayOfWeek?>,
        showModal: Binding<Bool>,
        navigationPath: Binding<NavigationPath>
    ) {
        self.customMapMarker = customMapMarker
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
        self._selectedDay = selectedDay
        self._showModal = showModal
        self._navigationPath = navigationPath
    }
    
    var body: some View {
        Group {
            if isLoadingData {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let island = selectedIsland {
                modalContent(island: island)

            } else {
                Text("Island unavailable.")
            }
        }
        .onAppear {
            loadIslandData()
        }
    }
    // MARK: - Async loading
    private func loadIslandData() {
        isLoadingData = true
        
        guard let island = selectedIsland else {
            isLoadingData = false
            return
        }
        
        Task {
            let hasSchedule = await viewModel.loadSchedules(for: island)
            
            async let fetchedAvgRating = ReviewUtils.fetchAverageRating(
                for: island,
                in: viewContext,
                callerFunction: "IslandModalView.onAppear"
            )
            
            async let fetchedReviews = ReviewUtils.fetchReviews(
                for: island,
                in: viewContext,
                callerFunction: "IslandModalView.onAppear"
            )
            
            let avgRating = await fetchedAvgRating
            let reviews = await fetchedReviews
            
            if let islandID = island.islandID {
                await MainActor.run {
                    _ = favoriteManager.isFavorite(islandID: islandID)
                }
            }
            
            await MainActor.run {
                scheduleExists = hasSchedule
                currentAverageStarRating = avgRating
                currentReviews = reviews
                isLoadingData = false
            }
        }
    }
     
    
    
    private func modalContent(island: PirateIsland) -> some View {
        List {

            // MARK: Header + Drag Handle
            Section {

                VStack(spacing: 8) {

                    Capsule()
                        .fill(.secondary.opacity(0.35))
                        .frame(width: 36, height: 5)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    HStack {

                        Button {
                            showModal = false
                            selectedIsland = nil   // ✅ ADD THIS
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if let islandID = island.islandID {
                            
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                    toggleFavorite(for: island)
                                }
                            } label: {
                                Image(
                                    systemName: favoriteManager.isFavorite(islandID: islandID)
                                    ? "heart.fill"
                                    : "heart"
                                )
                                .symbolEffect(.bounce, value: favoriteManager.isFavorite(islandID: islandID))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(
                                    favoriteManager.isFavorite(islandID: islandID)
                                    ? .red
                                    : .primary
                                )
                                .scaleEffect(
                                    favoriteManager.isFavorite(islandID: islandID) ? 1.2 : 1.0
                                )
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(.init())

                Button {
                    openInMaps(address: island.safeIslandLocation)
                } label: {

                    VStack(spacing: 6) {

                        Text(island.safeIslandName)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(island.safeIslandLocation)
                            .font(.callout)
                            .foregroundColor(.accentColor)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)


                if let gymWebsite = island.gymWebsite {
                    Link(destination: gymWebsite) {
                        Label("Visit Website", systemImage: "globe")
                    }
                }

            }

            // MARK: Fees
            Section {

                VStack(alignment: .leading, spacing: 6) {

                    HStack {

                        Text("Drop-In Fees")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(island.dropInDisplayText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(dropInColor(for: island).opacity(0.15))
                            .foregroundColor(dropInColor(for: island))
                            .clipShape(Capsule())
                    }

                    if island.dropInFeeAmount > 0,
                       let note = island.dropInFeeNote,
                       !note.trimmingCharacters(in: .whitespaces).isEmpty {

                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // MARK: Schedule
            Section {
                scheduleSection(for: island)
            }

            // MARK: Reviews
            Section {

                if !currentReviews.isEmpty {

                    HStack {

                        Text("Reviews")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()

                        let stars = StarRating.getStars(for: currentAverageStarRating)

                        HStack(spacing: 6) {

                            ForEach(stars, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }

                            Text(
                                "\(String(format: "%.1f", currentAverageStarRating)) • \(currentReviews.count) review\(currentReviews.count == 1 ? "" : "s")"
                            )
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        }
                    }
                    Button {
                        navigationPath.append(
                            AppScreen.viewAllReviews(
                                island.objectID.uriRepresentation().absoluteString
                            )
                        )
                        showModal = false
                    } label: {
                        Label("Read Gym Reviews", systemImage: "text.bubble")
                    }

                } else {

                    HStack {

                        Text("Reviews")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("No Reviews Yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        navigationPath.append(
                            AppScreen.review(
                                island.objectID.uriRepresentation().absoluteString
                            )
                        )
                        showModal = false
                    } label: {
                        Label("Be the First to Write a Review", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(8)
        .scrollContentBackground(.hidden)
    }
     

    private func scheduleSection(for island: PirateIsland) -> some View {
        
        let hasSchedules = (island.appDayOfWeeks as? Set<AppDayOfWeek>)?
            .contains(where: { $0.hasMatTimes }) ?? false
        
        return Button {
            if hasSchedules {
                navigationPath.append(
                    AppScreen.viewSchedule(
                        island.objectID.uriRepresentation().absoluteString
                    )
                )
                showModal = false
            } else {
                showNoScheduleAlert = true
            }
        } label: {
            Label("View Schedule", systemImage: "calendar")
        }
        .alert("No Schedule Added Yet",
               isPresented: $showNoScheduleAlert) {

            Button("Add Schedule") {
                navigationPath.append(
                    AppScreen.addSchedule(
                        island.objectID.uriRepresentation().absoluteString
                    )
                )
                showModal = false
            }

            Button("Cancel", role: .cancel) { }

        } message: {
            Text("Be the first to add this gym's schedule.")
        }
    }

    private func dropInColor(for island: PirateIsland) -> Color {
        switch island.dropInFeeStatus {
        case .notConfirmed:
            return .orange
        case .noDropInFee:
            return .red
        case .hasFee:
            return .green
        }
    }

    private func toggleFavorite(for island: PirateIsland) {

        guard let islandID = island.islandID else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        Task {
            if favoriteManager.isFavorite(islandID: islandID) {
                await favoriteManager.removeFavorite(islandID: islandID)
            } else {
                await favoriteManager.addFavorite(islandID: islandID)
            }
        }
    }
  
    private func openInMaps(address: String) {

        let encoded = address.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""

        if let googleURL = URL(string: "comgooglemaps://?q=\(encoded)"),
           UIApplication.shared.canOpenURL(googleURL) {

            UIApplication.shared.open(googleURL)
            return
        }

        if let appleURL = URL(string: "http://maps.apple.com/?address=\(encoded)") {
            UIApplication.shared.open(appleURL)
        }
    }
}

struct AddScheduleWrapperView: View {

    let island: PirateIsland

    @ObservedObject
    var viewModel: AppDayOfWeekViewModel

    @State private var selectedIslandID: String?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    init(
        island: PirateIsland,
        viewModel: AppDayOfWeekViewModel
    ) {
        self.island = island
        self.viewModel = viewModel

        _selectedIslandID = State(
            initialValue: island.islandID
        )
    }

    var body: some View {

        AddNewMatTimeSection2(
            selectedIslandID: $selectedIslandID,
            islands: [island],
            viewModel: viewModel,
            showAlert: $showAlert,
            alertTitle: $alertTitle,
            alertMessage: $alertMessage
        ) { island, day in

            return nil
        }
    }
}
