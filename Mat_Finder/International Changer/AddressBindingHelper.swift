// AddressBindingHelper.swift
// Mat_Finder
//
// Created by Brian Romero on 11/18/24.


import Foundation
import SwiftUI

// Helper class to manage the address binding logic
class AddressBindingHelper {
    /// Creates a binding for the specified address field.
    static func binding(for field: AddressField, islandDetails: Binding<IslandDetails>) -> Binding<String> {
        return islandDetails.transform(field.keyPath)
    }
}


/// Extension on Binding for IslandDetails.
extension Binding where Value == IslandDetails {
    func transform(_ keyPath: WritableKeyPath<IslandDetails, String>) -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}
