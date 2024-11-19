//
//  BannerView.swift
//  Seas_3
//
//  Created by Brian Romero on 11/14/24.
//

import Foundation
import UIKit
import GoogleMobileAds
import SwiftUI


struct BannerView: UIViewRepresentable {
func makeUIView(context: Context) -> GADBannerView {
    let bannerView = GADBannerView(adSize: GADAdSizeBanner)
    bannerView.adUnitID = "ca-app-pub-7376161442418831/2240344124"
    bannerView.rootViewController = context.coordinator.viewController // Fix
    bannerView.load(GADRequest())
    return bannerView
}

func updateUIView(_ uiView: GADBannerView, context: Context) {}

func makeCoordinator() -> Coordinator {
    Coordinator()
}

class Coordinator: NSObject {
    let viewController = UIViewController()
}
}
