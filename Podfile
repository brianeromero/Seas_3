platform :ios, '18.0'

target 'Seas_3' do
  use_frameworks!

  # ✅ Modular Firebase (subspecs instead of umbrella pods)
  pod 'Firebase/Analytics'
  pod 'Firebase/Auth'
  # pod 'Firebase/InAppMessaging' # <-- COMMENTED OUT
  pod 'Firebase/Firestore'
  pod 'Firebase/AppCheck'
  pod 'Firebase/Messaging'
  pod 'Firebase/Functions'
  pod 'Firebase/Crashlytics'

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
      # Set the minimum deployment target for all Pods to 18.0, 
      # matching the main project's platform setting.
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0' 
    end
  end
end
