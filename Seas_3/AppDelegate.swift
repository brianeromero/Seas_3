//
//  AppDelegate.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import UIKit
import CoreData

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register CustomUnarchiveTransformer
        ValueTransformer.setValueTransformer(CustomUnarchiveTransformer(), forName: NSValueTransformerName(rawValue: "CustomUnarchiveTransformer"))

        window = UIWindow(frame: UIScreen.main.bounds)
        let mainViewController = MainLoginViewController()
        window?.rootViewController = mainViewController
        window?.makeKeyAndVisible()

        return true
    }

    // Other methods...
}
