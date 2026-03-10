//  SceneLoader.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//
import Foundation
import SwiftUI

class SceneLoader {
    var tiles: [Tile] = []
    private let renderingManager = RenderingManager()

    func loadScene() {
        loadTiles()
        renderingManager.tiles = tiles
        renderingManager.assignMaterialsToMeshInstances()
    }

    // Function to load tiles (placeholder)
    private func loadTiles() {
        // Ensure the keys match those in the error message
        tiles = [
            Tile(key: "164.395.10.255", meshInstances: [MeshInstance(id: "1"), MeshInstance(id: "2")]),
            Tile(key: "163.395.10.255", meshInstances: [MeshInstance(id: "3"), MeshInstance(id: "4")]),
            // Add more tiles as needed to match all keys in the error message
        ]
        
        // Debug statements to confirm tiles are loaded
        for tile in tiles {
            print("Loaded tile with key: \(tile.key)")
        }
    }
}
