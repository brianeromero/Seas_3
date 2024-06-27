//
//  SceneLoader.swift
//  Seas_3
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
