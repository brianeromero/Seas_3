//
//  AdMobBannerAdd.swift
//  Seas_3
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import UIKit
import GoogleMobileAds


class ViewController: UIViewController {
    var bannerView: GADBannerView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create a banner view with the Ad unit ID
        bannerView = GADBannerView(adSize: GADAdSizeBanner) // Use GADAdSizeBanner
        bannerView.adUnitID = "ca-app-pub-7376161442418831/2240344124"
        bannerView.rootViewController = self
        view.addSubview(bannerView)

        // Load the ad
        bannerView.load(GADRequest())
    }
}
