//
//  MapControlsView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/10/26.
//

import SwiftUI
import MapKit


struct MapControlsView: View {

    let fitAction: () -> Void
    let listAction: (() -> Void)?

    @ObservedObject var userLocationVM: UserLocationMapViewModel

    var body: some View {

        VStack {
            Spacer()

            HStack {
                Spacer()

                VStack(spacing: 12) {

                    // 🌍 Fit Results
                    Button {
                        fitAction()
                    } label: {

                        Image(systemName: "arrow.up.left.and.arrow.down.right.rectangle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    }

                    // 📍 Recenter
                    RecenterMapButton(userLocationVM: userLocationVM)

                    // ☰ List (optional)
                    if let listAction {

                        Button {
                            listAction()
                        } label: {

                            Image(systemName: "list.bullet")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        }
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 90)
            .ignoresSafeArea(.keyboard)
        }
    }
}
