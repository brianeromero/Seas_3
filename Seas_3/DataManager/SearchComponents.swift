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

struct SearchHeader_Previews: PreviewProvider {
    static var previews: some View {
        SearchHeader()
            .previewLayout(.sizeThatFits)
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
    @Binding var showReview: Bool
    var title: String
    @StateObject private var viewModel: IslandListViewModel

    init(islands: [PirateIsland], selectedIsland: Binding<PirateIsland?>, showReview: Binding<Bool>, title: String, viewModel: IslandListViewModel = IslandListViewModel(persistenceController: PersistenceController.shared)) {
        self.islands = islands
        self._selectedIsland = selectedIsland
        self._showReview = showReview
        self.title = title
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        os_log("Rendering IslandList", log: logger)
        return NavigationStack {
            List {
                ForEach(islands, id: \.self) { island in
                    IslandListItem(island: island)
                        .onTapGesture {
                            os_log("Island selected: %@", log: logger, island.islandName ?? "Unknown")
                            selectedIsland = island
                            showReview = true
                            os_log("Setting showReview to true", log: logger)
                        }
                }
            }
            .navigationTitle(title)
            .navigationDestination(isPresented: $showReview) {
                destinationView
            }
        }
    }

    private var destinationView: some View {
        os_log("Rendering destination view", log: logger)
        if let selectedIsland = selectedIsland {
            return AnyView(ReviewDestinationView(viewModel: viewModel, selectedIsland: selectedIsland))
        } else {
            return AnyView(EmptyView())
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
                    selectedIsland: .constant(selectedIsland),
                    showReview: $showReview,
                    enterZipCodeViewModel: viewModel.enterZipCodeViewModel
                )
            } else {
                EmptyView()
            }
        }
    }
}


struct IslandList_Previews: PreviewProvider {
    static var previews: some View {
        os_log("Creating test island", log: logger)
        let context = PersistenceController.preview.container.viewContext
        let island = PirateIsland(context: context)
        island.islandName = "Test Island"
        island.islandLocation = "Test Location"

        return Group {
            IslandList(islands: [island], selectedIsland: .constant(nil), showReview: .constant(false), title: "Preview Title")
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Default")
                .onAppear {
                    os_log("Preview appeared", log: logger)
                }

            IslandList(islands: [island], selectedIsland: .constant(nil), showReview: .constant(false), title: "Canvas Preview Title")
                .previewLayout(.fixed(width: 400, height: 600))
                .previewDisplayName("Canvas Preview")
                .onAppear {
                    os_log("Canvas preview appeared", log: logger)
                }
        }
    }
}
