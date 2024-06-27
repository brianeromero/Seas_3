//
//  TESTMAPLOCATIONVIEW.swift
//  Seas_3
//
//  Created by Brian Romero on 6/27/24.
//

import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct TESTMAPLOCATIONVIEW: View {
    @State private var showMap = false

    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    showMap.toggle()
                }) {
                    Text("Show My Location")
                }
                .sheet(isPresented: $showMap) {
                    UserLocationMapView()
                }
            }
            .navigationTitle("Seas_3")
        }
    }
}

struct TESTMAPLOCATIONVIEW_Previews: PreviewProvider {
    static var previews: some View {
        TESTMAPLOCATIONVIEW()
    }
}
