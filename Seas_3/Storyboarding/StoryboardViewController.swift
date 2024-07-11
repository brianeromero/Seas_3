//
//  StoryboardViewController.swift
//  Seas_3
//
//  Created by Brian Romero on 7/10/24.
//

import Foundation
import UIKit

class StoryboardViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGlobalErrorHandler()
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
