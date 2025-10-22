//
//  BannerView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/14/24.
//

import Foundation
import UIKit
import GoogleMobileAds
import SwiftUI

struct BannerView: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Use the explicit name to avoid the naming conflict
        let bannerView = GoogleMobileAds.BannerView(adSize: AdSizeBanner)
        
        bannerView.adUnitID = "ca-app-pub-7376161442418831/2240344124"
        bannerView.rootViewController = context.coordinator.viewController
        
        bannerView.load(Request())
        
        return context.coordinator.viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        let viewController = UIViewController()
    }
}
