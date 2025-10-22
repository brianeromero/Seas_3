//
//  AdMobBannerAdd.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import UIKit
import GoogleMobileAds
import SwiftUI // Add SwiftUI import


class ViewController: UIViewController {
    var bannerView: GoogleMobileAds.BannerView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create a banner view with the Ad unit ID
        bannerView = GoogleMobileAds.BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = "ca-app-pub-7376161442418831/2240344124"
        bannerView.rootViewController = self
        view.addSubview(bannerView)

        // Load the ad
        bannerView.load(Request())
    }
}
