//
//  AllGymsListView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/10/26.
//

import SwiftUI


struct AllGymsListView: View {

    let islands: [PirateIsland]

    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool
    @Binding var searchText: String

    private var filteredIslands: [PirateIsland] {

        if searchText.isEmpty {
            return islands.sorted {
                $0.safeIslandName < $1.safeIslandName
            }
        }

        return islands
            .filter {
                $0.safeIslandName.localizedCaseInsensitiveContains(searchText) ||
                $0.safeIslandLocation.localizedCaseInsensitiveContains(searchText)
            }
            .sorted {
                $0.safeIslandName < $1.safeIslandName
            }
    }

    var body: some View {

        List {

            ForEach(filteredIslands, id: \.objectID) { island in

                Button {

                    selectedIsland = island
                    showModal = true

                } label: {

                    IslandListItem(
                        island: island,
                        selectedIsland: $selectedIsland
                    )
                    .padding(.vertical, 8)      // tighter like Gyms Near Me
                    .padding(.horizontal, 12)   // slightly reduced
                }
                .buttonStyle(.plain)
                .listRowInsets(.init())        // full width rows
                .listRowSeparator(.visible)    // match Apple Maps style
                .listRowBackground(Color(.systemBackground))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .ignoresSafeArea(.all, edges: .horizontal)
    }
}
