// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Seas_3",
    platforms: [.iOS(.v18), .macOS("10.15")],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.4.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "8.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "11.10.0"),
        .package(url: "https://github.com/facebook/facebook-ios-sdk.git", from: "17.4.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.3")
    ],
    targets: [
        .target(
            name: "Seas_3",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAppCheck", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "FacebookCore", package: "facebook-ios-sdk"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/Seas_3"
        ),
        .testTarget(
            name: "Seas_3Tests",
            dependencies: ["Seas_3"],
            path: "Tests/Seas_3Tests"
        )
    ]
)
