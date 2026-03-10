//  SharedTypes.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation

struct Tile {
    var key: String
    var meshInstances: [MeshInstance]
}

class MeshInstance {
    var id: String
    var material: Material?

    init(id: String, material: Material? = nil) {
        self.id = id
        self.material = material
    }
}

struct Material {
    // Material properties
}
