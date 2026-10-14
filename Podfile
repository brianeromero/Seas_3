platform :ios, '18.0'

target 'Mat_Finder' do
  use_frameworks! :linkage => :static

  # Firebase
  pod 'FirebaseAnalytics'
  pod 'FirebaseAuth'
  pod 'FirebaseFirestore'
  pod 'FirebaseFunctions'
  pod 'FirebaseCrashlytics'
  pod 'FirebaseMessaging'

  # Firebase App Check
  pod 'FirebaseAppCheck'
  pod 'FirebaseAppCheckInterop'

  # Google Sign-In
  pod 'GoogleSignIn'
  pod 'GoogleSignInSwift'

  # Facebook SDK
  pod 'FacebookCore'
  pod 'FacebookLogin'
  pod 'FacebookShare'

  # Google Mobile Ads
  pod 'Google-Mobile-Ads-SDK'

  # AppAuth
  pod 'AppAuth'
end

post_install do |installer|

  # Apply quoted-header setting to the Pods project
  installer.pods_project.build_configurations.each do |config|
    config.build_settings[
      'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'
    ] = 'NO'
  end

  # Configure individual Pods targets
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|

      # Set iOS deployment target
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'

      # Address quoted-header warnings
      config.build_settings[
        'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'
      ] = 'NO'

      # LevelDB C++ settings
      if target.name == 'leveldb-library'
        config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
        config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
      end

    end
  end
end