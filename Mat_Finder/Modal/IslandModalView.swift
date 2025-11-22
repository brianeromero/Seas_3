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
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Binding var selectedDay: DayOfWeek?
    @Binding var showModal: Bool
    @State private var isLoadingData: Bool = false
    @State private var showReview: Bool = false
    
    @State private var currentAverageStarRating: Double = 0.0
    @State private var currentReviews: [Review] = []
    
    @Binding var navigationPath: NavigationPath
    @State private var showNoScheduleAlert = false
    
    var isLoading: Bool {
        islandSchedules.isEmpty && !scheduleExists || isLoadingData
    }
    
    let customMapMarker: CustomMapMarker?
    @State private var scheduleExists: Bool = false
    @State private var islandSchedules: [(PirateIsland, [MatTime])] = []
    let islandName: String
    let islandLocation: String
    let formattedCoordinates: String
    let createdTimestamp: String
    let formattedTimestamp: String
    let gymWebsite: URL?
    let dayOfWeekData: [DayOfWeek]
    
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @ObservedObject private var authViewModel = AuthViewModel.shared
    
    init(
        customMapMarker: CustomMapMarker?,
        islandName: String,
        islandLocation: String,
        formattedCoordinates: String,
        createdTimestamp: String,
        formattedTimestamp: String,
        gymWebsite: URL?,
        dayOfWeekData: [DayOfWeek],
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>,
        viewModel: AppDayOfWeekViewModel,
        selectedDay: Binding<DayOfWeek?>,
        showModal: Binding<Bool>,
        enterZipCodeViewModel: EnterZipCodeViewModel,
        navigationPath: Binding<NavigationPath>
    ) {
        self.customMapMarker = customMapMarker
        self.islandName = islandName
        self.islandLocation = islandLocation
        self.formattedCoordinates = formattedCoordinates
        self.createdTimestamp = createdTimestamp
        self.formattedTimestamp = formattedTimestamp
        self.gymWebsite = gymWebsite
        self.dayOfWeekData = dayOfWeekData
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
        self._selectedDay = selectedDay
        self._showModal = showModal
        self.enterZipCodeViewModel = enterZipCodeViewModel
        self._navigationPath = navigationPath
    }


    var body: some View {
        ZStack {
            // Dimmed blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { showModal = false }

            contentView
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Dismiss") { showModal = false }
            }
        }
        .navigationTitle(selectedIsland?.islandName ?? "Island Details")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(false)
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
            
            let avgRating = Double(await fetchedAvgRating)
            let reviews = await fetchedReviews
            
            await MainActor.run {
                scheduleExists = hasSchedule
                currentAverageStarRating = avgRating
                currentReviews = reviews
                isLoadingData = false
            }
        }
    }


    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        if isLoadingData {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .frame(width: 200, height: 80)
                ProgressView("Loading schedules...")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let island = selectedIsland, selectedDay != nil {
            modalContent(island: island)
        } else {
            Text("Error: selectedIsland or selectedDay is nil.")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    
    private func modalContent(island: PirateIsland) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(islandName)
                .font(.system(size: 20, weight: .bold))
                .fontDesign(.rounded)
                .foregroundColor(.primary)

            locationSection
            websiteSection
            scheduleSection(for: island)
            reviewsSection

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .frame(maxWidth: 600, maxHeight: 600)
        .overlay(alignment: .topTrailing) {
            closeButton
        }
    }

    
    private var locationSection: some View {
        Button(action: { openInMaps(address: islandLocation) }) {
            Text(islandLocation)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.accentColor)
                .underline() // optional, looks more like a typical hyperlink
        }
        .buttonStyle(.plain)
    }
    
    private var websiteSection: some View {
        Group {
            if let gymWebsite = gymWebsite {
                HStack {
                    Text("Website:")
                        .foregroundColor(.primary)
                        .font(.system(size: 16, weight: .semibold))
                        .fontDesign(.rounded)

                    Spacer()

                    Link("Visit Website", destination: gymWebsite)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .underline() // optional, looks more like a typical hyperlink
                }
                .padding(.top, 10)
            } else {
                Text("No website available.")
                    .font(.system(size: 16, weight: .semibold))
                    .fontDesign(.rounded)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
            }
        }
    }

    private func scheduleSection(for island: PirateIsland) -> some View {
        let hasSchedules = (island.appDayOfWeeks as? Set<AppDayOfWeek>)?
            .contains(where: { $0.hasMatTimes }) ?? false
        
        return AnyView(
            content(for: island, hasSchedules: hasSchedules)
                .alert(
                    "Schedule Not Available",
                    isPresented: $showNoScheduleAlert
                ) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("There are no scheduled mat times associated with this gym.")
                }
        )
    }
    

    @ViewBuilder
    private func content(for island: PirateIsland, hasSchedules: Bool) -> some View {
        if hasSchedules {
            NavigationLink(
                destination: ViewScheduleForIsland(viewModel: viewModel, island: island)
            ) {
                Text("View Schedule")
                    .font(.system(size: 16, weight: .semibold))
                    .fontDesign(.rounded)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor.opacity(0.1)) // optional visual styling
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showNoScheduleAlert = true
            } label: {
                Text("View Schedule")
                    .font(.system(size: 16, weight: .semibold))
                    .fontDesign(.rounded)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gray.opacity(0.2)) // optional styling for disabled
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // WHEN REVIEWS EXIST
            if !currentReviews.isEmpty {
                HStack {
                    Text("Average Rating:")
                        .foregroundColor(.primary)
                        .font(.system(size: 16, weight: .semibold))
                        .fontDesign(.rounded)

                    Spacer()

                    HStack(spacing: 2) {
                        let starIcons = StarRating.getStars(for: currentAverageStarRating)
                        ForEach(starIcons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .foregroundColor(.yellow)
                        }
                    }
                }

                if let island = selectedIsland {
                    Button {
                        navigationPath.append(
                            AppScreen.viewAllReviews(
                                island.objectID.uriRepresentation().absoluteString
                            )
                        )
                        showModal = false
                    } label: {
                        Text("View All Reviews")
                            .font(.system(size: 16, weight: .semibold))
                            .fontDesign(.rounded)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

            } else {
                // WHEN NO REVIEWS EXIST
                Text("No reviews available.")
                    .font(.system(size: 16, weight: .semibold))
                    .fontDesign(.rounded)
                    .foregroundColor(.secondary)

                if let island = selectedIsland {
                    Button {
                        navigationPath.append(
                            AppScreen.review(
                                island.objectID.uriRepresentation().absoluteString
                            )
                        )
                        showModal = false
                    } label: {
                        Text("Be the first to write a review!")
                            .font(.system(size: 16, weight: .semibold))
                            .fontDesign(.rounded)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 20)
    }



    private var closeButton: some View {
        Button {
            showModal = false
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(8)
        }
    }

    
    private func openInMaps(address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
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
