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
                .onChange(of: text) { newText in
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
    @Binding var selectedIsland: PirateIsland?
    @Binding var searchText: String
    let navigationDestination: NavigationDestination
    let title: String
    let enterZipCodeViewModel: EnterZipCodeViewModel
    let authViewModel: AuthViewModel
    let onIslandChange: (PirateIsland?) -> Void // Change here
    @State private var showNavigationDestination = false

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
        NavigationStack {
            List {
                ForEach(filteredIslands, id: \.self) { island in
                    Button(action: {
                        selectedIsland = island
                        onIslandChange(selectedIsland) // Change here
                        showNavigationDestination = true
                    }) {
                        IslandListItem(island: island, selectedIsland: $selectedIsland)
                    }
                }
            }
            .navigationTitle(title)
            .navigationDestination(isPresented: $showNavigationDestination) {
                if let island = selectedIsland {
                    switch self.navigationDestination {
                    case .editExistingIsland:
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
                    case .viewReviewForIsland:
                        ViewReviewforIsland(
                            showReview: .constant(true),
                            selectedIsland: $selectedIsland,
                            enterZipCodeViewModel: enterZipCodeViewModel,
                            authViewModel: authViewModel
                        )
                    case .review:
                        GymMatReviewView(
                            localSelectedIsland: $selectedIsland,
                            enterZipCodeViewModel: enterZipCodeViewModel,
                            authViewModel: authViewModel,
                            onIslandChange: onIslandChange
                        )
                    }
                } else {
                    EmptyView()
                }
            }
        }
    }
}

struct ReviewDestinationView: View {
    @ObservedObject var viewModel: IslandListViewModel
    let selectedIsland: PirateIsland?
    @State private var showReview: Bool = false
    
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
                    showReview: $showReview, selectedIsland: .constant(selectedIsland),
                    enterZipCodeViewModel: viewModel.enterZipCodeViewModel, authViewModel: AuthViewModel()
                )
            } else {
                EmptyView()
            }
        }
    }
}

struct IslandList_Previews: PreviewProvider {
    struct Preview: View {
        @State private var searchText = ""

        var body: some View {
            os_log("Creating test island", log: logger)
            let context = PersistenceController.preview.container.viewContext
            let island = PirateIsland(context: context)
            island.islandName = "Test Island"
            island.islandLocation = "Test Location"

            let enterZipCodeViewModel = EnterZipCodeViewModel(
                repository: AppDayOfWeekRepository(
                    persistenceController: PersistenceController.preview
                ),
                persistenceController: PersistenceController.preview
            )

            let authViewModel = AuthViewModel.shared

            return Group {
                IslandList(
                    islands: [island],
                    selectedIsland: .constant(nil),
                    searchText: $searchText,
                    navigationDestination: .editExistingIsland,
                    title: "Preview Title",
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    authViewModel: authViewModel,
                    onIslandChange: { island in
                        os_log("Island changed: %@", log: logger, island?.islandName ?? "")
                    }
                )
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Default")
                .onAppear {
                    os_log("Preview appeared", log: logger)
                }

                IslandList(
                    islands: [island],
                    selectedIsland: .constant(nil),
                    searchText: $searchText,
                    navigationDestination: .viewReviewForIsland,
                    title: "Canvas Preview Title",
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    authViewModel: authViewModel,
                    onIslandChange: { island in
                        os_log("Island changed: %@", log: logger, island?.islandName ?? "")
                    }
                )
                .previewLayout(.fixed(width: 400, height: 600))
                .previewDisplayName("Canvas Preview")
                .onAppear {
                    os_log("Canvas preview appeared", log: logger)
                }
            }
        }
    }

    static var previews: some View {
        Preview()
    }
}

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SearchBar(text: .constant("Search..."))
                .previewLayout(.sizeThatFits)
                .previewDisplayName("With Text")

            SearchBar(text: .constant(""))
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Empty Text")

            SearchBar(text: .constant("Canvas Preview"))
                .previewLayout(.fixed(width: 300, height: 100))
                .previewDisplayName("Canvas Preview")
        }
    }
}

struct SearchHeader_Previews: PreviewProvider {
    static var previews: some View {
        SearchHeader()
            .previewLayout(.sizeThatFits)
    }
}

// New View for Selected Island
enum DestinationView {
    case gymMatReview
    case viewReviewForIsland
}

// New View for Selected Island
struct SelectedIslandView: View {
    let island: PirateIsland
    @Binding var selectedIsland: PirateIsland?  // Change to @Binding
    var enterZipCodeViewModel: EnterZipCodeViewModel
    var onIslandChange: (PirateIsland?) -> Void
    var authViewModel: AuthViewModel
    var destinationView: DestinationView

    var body: some View {
        switch destinationView {
        case .gymMatReview:
            GymMatReviewView(
                localSelectedIsland: $selectedIsland,  // Bind to selectedIsland
                enterZipCodeViewModel: enterZipCodeViewModel,
                authViewModel: authViewModel,
                onIslandChange: onIslandChange
            )
        case .viewReviewForIsland:
            ViewReviewforIsland(
                showReview: .constant(false),
                selectedIsland: $selectedIsland,
                enterZipCodeViewModel: enterZipCodeViewModel,
                authViewModel: authViewModel
            )
        }
    }
}
