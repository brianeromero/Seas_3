platform :ios, '18.0'

target 'Seas_3' do
  use_frameworks!

  # ✅ Modular Firebase
  pod 'FirebaseAnalytics', '~> 10.0'
  pod 'FirebaseAuth', '~> 10.0'
  pod 'FirebaseInAppMessaging', '10.0.0-beta'
  pod 'FirebaseFirestore', '10.24.0'
  pod 'FirebaseAppCheck'
  pod 'FirebaseMessaging', '~> 10.0'
  pod 'FirebaseFunctions', '~> 10.0'
pod 'FirebaseCrashlytics', '~> 10.0'


  # ✅ Google Sign-In (Core + SwiftUI Button)
  pod 'GoogleSignIn'         # Required for authentication logic
  pod 'GoogleSignInSwift'    # Optional: SwiftUI button

  # ✅ Facebook SDK
  pod 'FacebookCore'
  pod 'FacebookLogin'
  pod 'FacebookShare'

  # ✅ Google Mobile Ads (AdMob)
  pod 'Google-Mobile-Ads-SDK', '~> 11.10'

  # ✅ AppAuth for OAuth / OpenID Connect
  pod 'AppAuth', '~> 1.6'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
      config.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
      config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
      config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        '_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION'
      ]
    end

    # 🧹 Clean up flags for BoringSSL-GRPC
    if target.name == 'BoringSSL-GRPC'
      target.source_build_phase.files.each do |file|
        if file.settings && file.settings['COMPILER_FLAGS']
          file.settings['COMPILER_FLAGS'] = file.settings['COMPILER_FLAGS']
            .gsub(/-G/, '')
            .gsub(/CC_WARN_INHIBIT_ALL_WARNINGS/, '')
        end
      end
    end
  end

  # 🩹 Patch incorrect function calls in GDTCORClock.m
  clock_file = 'Pods/GoogleDataTransport/GoogleDataTransport/GDTCORLibrary/GDTCORClock.m'
  if File.exist?(clock_file)
    text = File.read(clock_file)
    text.gsub!(/\bKernelBootTimeInNanoseconds\s*\(\s*void\s*\)/, 'KernelBootTimeInNanoseconds()')
    text.gsub!(/\bUptimeInNanoseconds\s*\(\s*void\s*\)/, 'UptimeInNanoseconds()')
    File.write(clock_file, text)
  end

  # 🩹 Patch incorrect template usage in gRPC-Core's basic_seq.h
  grpc_file = 'Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h'
  if File.exist?(grpc_file)
    contents = File.read(grpc_file)
    contents.gsub!(
      /Traits::template CallSeqFactory<[^>]+>\(/,
      'Traits::CallSeqFactory('
    )
    File.write(grpc_file, contents)
    puts "✅ Fixed CallSeqFactory template misuse in #{grpc_file}"
  end
end
