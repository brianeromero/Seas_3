//
//  PirateIslandView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine

struct PirateIslandView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            if appState.showWelcomeScreen {
                Text("Mat_Finder")
                    .font(.largeTitle)
                    .padding()
                    .onAppear {
                        print("👀 PirateIslandView showing Mat_Finder at \(Date())")
                    }
                    .onDisappear {
                        print("👋 Mat_Finder disappeared at \(Date())")
                    }
            } else {
                NavigationView {
                    Text("Where All Your Mat Dreams Come True!!!")
                        .padding()
                        .navigationBarTitle("Mat Finder")
                        .onAppear {
                            print("✅ NavigationView appeared at \(Date())")
                        }
                }
            }
        }
    }
}
