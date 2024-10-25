//
//  StoryboardViewController.swift
//  Seas_3
//
//  Created by Brian Romero on 7/10/24.
//

import Foundation
import UIKit
import FirebaseAnalytics // Import FirebaseAnalytics

class StoryboardViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGlobalErrorHandler()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Log screen view event
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: "StoryboardViewController",
            AnalyticsParameterScreenClass: String(describing: StoryboardViewController.self)
        ])
    }
    
    private func setupGlobalErrorHandler() {
        NSSetUncaughtExceptionHandler { exception in
            if let reason = exception.reason,
               reason.contains("has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API") {
                NSLog("Caught NaN error: %@", reason)
            }
        }
    }
    
    // Other methods and functionality of your StoryboardViewController
}
