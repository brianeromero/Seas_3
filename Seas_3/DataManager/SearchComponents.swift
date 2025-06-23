//
//  SearchComponents.swift
//  Seas_3
//
//  Created by Brian Romero on 9/28/24.
//

import Foundation
import SwiftUI
import os.log


// Create a logger
let logger = OSLog(subsystem: "MF-inder.Seas-3", category: "SearchComponents")


enum NavigationDestination {
    case review
    case editExistingIsland
    case viewReviewForIsland
}

struct SearchHeader: View {
    var body: some View {
        Text("Search by: gym name, postal code, or address/location")
            .font(.headline)
            .padding(.bottom, 4)
            .foregroundColor(.gray)
            .padding(.horizontal, 8)
    }
}


struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            GrayPlaceholderTextField("Search...", text: $text)
            if !text.isEmpty {
                Button(action: {
                    os_log("Clear button tapped", log: logger)
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .onAppear {
            os_log("SearchBar appeared", log: logger)
        }
    }
}

struct GrayPlaceholderTextField: View {
    private let placeholder: String
    @Binding private var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
            }
            TextField("", text: $text)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8.0)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: text) { newText, _ in
                    os_log("Text changed: %@", log: logger, newText)
                }
        }
        .onAppear {
            os_log("GrayPlaceholderTextField appeared", log: logger)
        }
    }
}


class IslandListViewModel: ObservableObject {
    static let shared = IslandListViewModel(persistenceController: PersistenceController.shared)
    
    let repository: AppDayOfWeekRepository
    let enterZipCodeViewModel: EnterZipCodeViewModel
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        os_log("Initializing IslandListViewModel", log: logger)
        self.persistenceController = persistenceController
        self.repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        self.enterZipCodeViewModel = EnterZipCodeViewModel(repository: repository, persistenceController: persistenceController)
        os_log("Initialized IslandListViewModel", log: logger)
    }
}

struct IslandListItem: View {
    let island: PirateIsland
    @Binding var selectedIsland: PirateIsland?

    var body: some View {
        os_log("Rendering IslandListItem for %@", log: logger, island.islandName ?? "Unknown")
        return VStack(alignment: .leading) {
            Text(island.islandName ?? "Unknown Gym")
                .font(.headline)
            Text(island.islandLocation ?? "")
                .font(.subheadline)
                .lineLimit(nil)
        }
    }
}

struct IslandList: View {
    let islands: [PirateIsland]
    @Binding var selectedIsland: PirateIsland? // This is the source of the value
    @Binding var searchText: String
    let navigationDestination: NavigationDestination
    let title: String
    let enterZipCodeViewModel: EnterZipCodeViewModel
    let authViewModel: AuthViewModel
    let onIslandChange: (PirateIsland?) -> Void
    @State private var showNavigationDestination = false
    
    // Add NavigationPath state here to pass to ViewReviewforIsland
    @State private var navigationPath = NavigationPath()

    var filteredIslands: [PirateIsland] {
        if searchText.isEmpty {
            return islands
        } else {
            return islands.filter { island in
                island.islandName?.lowercased().contains(searchText.lowercased()) ?? false ||
                island.islandLocation?.lowercased().contains(searchText.lowercased()) ?? false
            }
        }
    }

    var body: some View {
        List {
            ForEach(filteredIslands, id: \.self) { island in
                Button(action: {
                    selectedIsland = island
                    onIslandChange(selectedIsland)
                    showNavigationDestination = true
                }) {
                    IslandListItem(island: island, selectedIsland: $selectedIsland)
                }
            }
        }
        .navigationTitle(title)
        .navigationDestination(isPresented: $showNavigationDestination) {
            switch self.navigationDestination {
            case .editExistingIsland:
                if let island = selectedIsland {
                    EditExistingIsland(
                        island: island,
                        islandViewModel: PirateIslandViewModel(
                            persistenceController: PersistenceController.shared
                        ),
                        profileViewModel: ProfileViewModel(
                            viewContext: PersistenceController.shared.container.viewContext,
                            authViewModel: authViewModel
                        )
                    )
                } else {
                    EmptyView()
                }
                
            case .viewReviewForIsland:
                // Pass the navigationPath binding here
                ViewReviewforIsland(
                    showReview: .constant(true),
                    selectedIsland: selectedIsland!,
                    navigationPath: $navigationPath
                )

            case .review:
                GymMatReviewView(
                    localSelectedIsland: $selectedIsland,
                    //onIslandChange: onIslandChange
                )
            }
        }
    }
}

struct ReviewDestinationView: View {
    @ObservedObject var viewModel: IslandListViewModel
    let selectedIsland: PirateIsland?
    @State private var showReview: Bool = false
    
    // Add NavigationPath here
    @State private var navigationPath = NavigationPath()
    
    init(viewModel: IslandListViewModel, selectedIsland: PirateIsland?) {
        os_log("ReviewDestinationView initialized with island: %@", log: logger, selectedIsland?.islandName ?? "Unknown")
        self.viewModel = viewModel
        self.selectedIsland = selectedIsland
    }

    var body: some View {
        os_log("Rendering ReviewDestinationView", log: logger)
        return VStack {
            if let selectedIsland = selectedIsland {
                ViewReviewforIsland(
                    showReview: $showReview,
                    selectedIsland: selectedIsland,
                    navigationPath: $navigationPath
                )
            } else {
                EmptyView()
            }
        }
    }
}


// New View for Selected Island
enum DestinationView {
    case gymMatReview
    case viewReviewForIsland
}


struct SelectedIslandView: View {
    let island: PirateIsland
    @Binding var selectedIsland: PirateIsland?
    var enterZipCodeViewModel: EnterZipCodeViewModel
    var onIslandChange: (PirateIsland?) -> Void
    var authViewModel: AuthViewModel
    var destinationView: DestinationView
    
    // Add navigationPath here
    @State private var navigationPath = NavigationPath()

    var body: some View {
        switch destinationView {
        case .gymMatReview:
            GymMatReviewView(
                localSelectedIsland: $selectedIsland,
                //onIslandChange: onIslandChange
            )
        case .viewReviewForIsland:
            ViewReviewforIsland(
                showReview: .constant(false),
                selectedIsland: island,
                navigationPath: $navigationPath
            )
        }
    }
}
