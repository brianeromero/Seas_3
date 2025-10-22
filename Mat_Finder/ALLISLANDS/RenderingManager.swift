//  RenderingManager.swift
//  Mat_Finder
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
                let meshInstance = tiles[tileIndex].meshInstances[meshInstanceIndex]
                if let material = loadMaterial(for: meshInstance) {
                    tiles[tileIndex].meshInstances[meshInstanceIndex].material = material
                    print("Assigned material to meshInstance \(meshInstance.id) in tile \(tiles[tileIndex].key)")
                } else {
                    print("Pending material for meshInstance \(meshInstance.id) in tile \(tiles[tileIndex].key)")
                }
            }
        }
    }

    // Example function to load material
    private func loadMaterial(for meshInstance: MeshInstance) -> Material? {
        // Logic to load and return the appropriate material
        // Return nil if material is not yet ready
        // For debugging purposes, we return nil for every alternate call
        return arc4random_uniform(2) == 0 ? Material() : nil // Placeholder for actual material loading logic
    }

    // Function to load tiles (placeholder)
    private func loadTiles() {
        // Logic to load and initialize tiles
        // This should populate the tiles array
        tiles = [
            Tile(key: "164.395.10.255", meshInstances: [MeshInstance(id: "1"), MeshInstance(id: "2")]),
            Tile(key: "163.395.10.255", meshInstances: [MeshInstance(id: "3"), MeshInstance(id: "4")]),
            // Add more tiles as needed
        ]
        
        // Debug statements to confirm tiles are loaded
        for tile in tiles {
            print("Loaded tile with key: \(tile.key)")
        }
    }
}
