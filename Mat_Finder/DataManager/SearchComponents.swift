//
//  SearchComponents.swift
//  Mat_Finder
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

@MainActor
class IslandListViewModel: ObservableObject {
    static let shared = IslandListViewModel(persistenceController: PersistenceController.shared)
    
    let repository: AppDayOfWeekRepository
    let enterZipCodeViewModel: EnterZipCodeViewModel
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        os_log("Initializing IslandListViewModel", log: logger)
        self.persistenceController = persistenceController
        self.repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        self.enterZipCodeViewModel = EnterZipCodeViewModel(
            repository: repository,
            persistenceController: persistenceController
        )
        os_log("Initialized IslandListViewModel", log: logger)
    }
}


struct IslandListItem: View {
    @ObservedObject var island: PirateIsland // <-- CHANGE THIS!
    @Binding var selectedIsland: PirateIsland?

    var body: some View {
        os_log("Rendering IslandListItem for %@", log: logger, island.islandName ?? "Unknown")
        return VStack(alignment: .leading) {
            Text(island.islandName ?? "Unknown Gym") // Now this Text view will re-render
                .font(.headline)
            Text(island.islandLocation ?? "")       // when island.islandLocation changes
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
    
    // ✅ Change these to @EnvironmentObject as they are shared app-wide
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var pirateIslandViewModel: PirateIslandViewModel // Needed for EditExistingIsland
    @EnvironmentObject var profileViewModel: ProfileViewModel // Needed for EditExistingIsland

    let onIslandChange: (PirateIsland?) -> Void
    
    // ✅ NEW: Receive navigationPath as a Binding from the parent view
    @Binding var navigationPath: NavigationPath // <--- CRUCIAL CHANGE!

    // !!! NEW: Bindings to control the toast from the parent view (EditExistingIslandListContent) !!!
    @Binding var showSuccessToast: Bool
    @Binding var successToastMessage: String
    @Binding var successToastType: ToastView.ToastType // <<< NEW: Add this binding

    init(
        islands: [PirateIsland],
        selectedIsland: Binding<PirateIsland?>,
        searchText: Binding<String>,
        navigationDestination: NavigationDestination,
        title: String,
        onIslandChange: @escaping (PirateIsland?) -> Void,
        navigationPath: Binding<NavigationPath>, // Receive navigationPath here
        // !!! NEW: Add the new toast bindings to the initializer !!!
        showSuccessToast: Binding<Bool>,
        successToastMessage: Binding<String>,
        successToastType: Binding<ToastView.ToastType> // <<< NEW: Add the new toast binding
    ) {
        self.islands = islands
        self._selectedIsland = selectedIsland
        self._searchText = searchText
        self.navigationDestination = navigationDestination
        self.title = title
        self.onIslandChange = onIslandChange
        self._navigationPath = navigationPath // Initialize the binding
        self._showSuccessToast = showSuccessToast // Initialize the new toast binding
        self._successToastMessage = successToastMessage // Initialize the new toast binding
        self._successToastType = successToastType // <<< NEW: Initialize the new toast binding
    }

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
        VStack(alignment: .leading, spacing: 0) { // ✅ spacing: 0 for no space between elements
            // The title is now part of this view's layout, not the parent's navigationTitle.
            Text(title)
                .font(.title2)
                .bold()
                .padding(.horizontal, 16) // Padding for title
                .padding(.bottom, 8) // Spacing below title

            List {
                ForEach(filteredIslands, id: \.objectID) { island in // ✅ Use .objectID for stable identity
                    // ✅ Replaced Button with NavigationLink(value: ...)
                    NavigationLink(value: AppScreen.editExistingIsland(island.objectID.uriRepresentation().absoluteString)) {
                        IslandListItem(island: island, selectedIsland: $selectedIsland)
                            // Apply styling to the row content itself
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) // ✅ CRITICAL: Removes row padding
                            .listRowBackground(Color(.systemBackground)) // ✅ CRITICAL: Dynamic background for row
                    }
                    .buttonStyle(PlainButtonStyle()) // Ensures the whole row is tappable and removes default blue tint
                }
            }

            .listStyle(.plain) // ✅ CRITICAL: Flat list style
            .background(Color(.systemBackground)) // ✅ CRITICAL: List background matches system theme
            .padding(.horizontal, 0) // ✅ CRITICAL: No horizontal padding on the List itself
            .ignoresSafeArea(.all, edges: .horizontal) // ✅ CRITICAL: Extends list content to screen edges
        }
        // ✅ REMOVED: .navigationTitle(title) // This should be on the parent view that contains this list (e.g., EditExistingIslandListContent)
        // ✅ REMOVED: .navigationDestination(isPresented: ...) // This is now handled by AppRootView's .navigationDestination(for:)
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
