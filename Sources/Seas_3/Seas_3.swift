import UIKit
import Firebase
import GoogleSignIn
import GoogleMobileAds
import Facebook
import CryptoSwift

@main
class Seas_3: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties
    
    var window: UIWindow?
    
    // MARK: - Lifecycle Methods
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Load configuration settings
        let config = Bundle.main.infoDictionary
        
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize Google Sign-In
        GIDConfiguration.sharedInstance.clientID = config?["GIDClientID"] as? String
        
        // Initialize Google Mobile Ads
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        
        // Initialize Facebook
        let facebookAppID = config?["FacebookAppID"] as? String
        let facebookClientToken = config?["FacebookClientToken"] as? String
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions,
            facebookAppID: facebookAppID,
            facebookClientToken: facebookClientToken
        )
        
        return true
    }
    
    // MARK: - UIApplicationDelegate
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .all
    }
}
