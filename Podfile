platform :ios, '18.0'

target 'Seas_3' do
  use_frameworks!

  # Firebase dependencies
  pod 'Firebase/Analytics'
  pod 'Firebase/Auth'
  pod 'Firebase/InAppMessaging' # Included from the second file

  # Google Sign-In dependencies
  pod 'GoogleSignIn'
  pod 'GoogleSignInSwift' # Includes Swift package support
  pod 'AppAuth'
  pod 'GTMAppAuth'

  # Facebook SDK (Full Suite)
  pod 'FacebookCore'
  pod 'FacebookLogin'
  pod 'FacebookShare'

  # Google Mobile Ads SDK (AdMob)
  pod 'Google-Mobile-Ads-SDK'
end

# Ensure minimum deployment target for all pods
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    end
  end
end