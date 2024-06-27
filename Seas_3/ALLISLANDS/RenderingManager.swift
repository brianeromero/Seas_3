//
//  RenderingManager.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

class RenderingManager {
    var tiles: [Tile] = []

    // Initialize the manager and load the tiles
    init() {
        loadTiles()
        assignMaterialsToMeshInstances()
    }

    // Function to assign materials to mesh instances
    func assignMaterialsToMeshInstances() {
        for tileIndex in tiles.indices {
            for meshInstanceIndex in tiles[tileIndex].meshInstances.indices {
                if let material = loadMaterial(for: tiles[tileIndex].meshInstances[meshInstanceIndex]) {
                    tiles[tileIndex].meshInstances[meshInstanceIndex].material = material
                } else {
                    print("Pending material for meshInstance \(tiles[tileIndex].meshInstances[meshInstanceIndex].id) in tile \(tileIndex)")
                }
            }
        }
    }

    // Example function to load material
    private func loadMaterial(for meshInstance: MeshInstance) -> Material? {
        // Logic to load and return the appropriate material
        // Return nil if material is not yet ready
        return Material() // Placeholder for actual material loading logic
    }

    // Function to load tiles (placeholder)
    private func loadTiles() {
        // Logic to load and initialize tiles
        // This should populate the tiles array
        tiles = [
            Tile(key: "654.1583.12.255", meshInstances: [MeshInstance(id: "1"), MeshInstance(id: "2")]),
            Tile(key: "655.1582.12.255", meshInstances: [MeshInstance(id: "3"), MeshInstance(id: "4")]),
            Tile(key: "654.1582.12.255", meshInstances: [MeshInstance(id: "5"), MeshInstance(id: "6")]),
            Tile(key: "655.1583.12.255", meshInstances: [MeshInstance(id: "7"), MeshInstance(id: "8")])
        ]
    }
}
