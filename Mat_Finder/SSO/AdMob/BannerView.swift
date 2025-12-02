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
    
    // Creates the view controller that manages the GADBannerView
    func makeUIViewController(context: Context) -> AdBannerViewController {
        return AdBannerViewController()
    }
    
    // Updates the view controller (typically not needed for a static banner ad)
    func updateUIViewController(_ uiViewController: AdBannerViewController, context: Context) {}
}

final class AdBannerViewController: UIViewController {
    // The Google Mobile Ad View
    let bannerView = GoogleMobileAds.BannerView(adSize: AdSizeBanner)
    
    // The Ad Unit ID for the banner ad. Use your production ID here.
    private let adUnitID = "ca-app-pub-7376161442418831/8349985070"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Configure the banner view
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = self // Required to display the ad
        
        // 2. Add the banner view to the view hierarchy
        view.addSubview(bannerView)
        
        // 3. Request an ad
        let request = Request()
        bannerView.load(request)
        
        // Ensure the background is clear so the ad background is visible.
        view.backgroundColor = .clear
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Center the banner ad within the hosting view (which is 50pts high)
        let adSize = bannerView.adSize
        let originX = (view.frame.size.width - adSize.size.width) / 2
        
        bannerView.frame = CGRect(
            x: originX,
            y: 0,
            width: adSize.size.width,
            height: adSize.size.height
        )
    }
}
