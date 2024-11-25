//
//  AddressFieldView.swift
//  Seas_3
//
//  Created by Brian Romero on 11/22/24.
//

import Foundation
import SwiftUI

struct AddressFieldView: View {
    let field: AddressField
    @Binding var islandDetails: IslandDetails
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(field.rawValue.capitalized)
            TextField("Enter \(field.rawValue.capitalized)", text: binding(for: field))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onChange(of: binding(for: field).wrappedValue) { newValue in
                    print("Field \(field.rawValue) updated to: \(newValue)")  // Log field changes
                }
        }
    }
    
    func binding(for field: AddressField) -> Binding<String> {
        return AddressBindingHelper.binding(for: field, islandDetails: $islandDetails)
    }
}
