//
//  StoryboardViewControllerRepresentable.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/12/24.
//


import Foundation
import SwiftUI
import UIKit


struct StoryboardViewControllerRepresentable: UIViewControllerRepresentable {
    let storyboardName: String
    
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        guard let viewController = storyboard.instantiateInitialViewController() else {
            fatalError("Failed to instantiate initial view controller from storyboard: \(storyboardName)")
        }
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the view controller if needed
    }
}


