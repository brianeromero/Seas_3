platform :ios, '18.0'

target 'Seas_3' do
  use_frameworks!

  # ✅ Modular Firebase (using individual pods, highly recommended)
  pod 'FirebaseAnalytics'
  pod 'FirebaseAuth'
  pod 'FirebaseFirestore'
  pod 'FirebaseFunctions'
  pod 'FirebaseCrashlytics'
  pod 'FirebaseMessaging'
  
  # 💡 THE APP CHECK FIX: Use the core pod and the provider interop pod
  pod 'FirebaseAppCheck'
  pod 'FirebaseAppCheckInterop'
  
  # Note: The factory class you need is now included in the core or interop pods.
  
  # ✅ Google Sign-In
  pod 'GoogleSignIn'
  pod 'GoogleSignInSwift'

  # ✅ Facebook SDK
  pod 'FacebookCore'
  pod 'FacebookLogin'
  pod 'FacebookShare'

  # ✅ Google Mobile Ads
  pod 'Google-Mobile-Ads-SDK'

  # ✅ AppAuth
  pod 'AppAuth'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0' 
    end
  end
end