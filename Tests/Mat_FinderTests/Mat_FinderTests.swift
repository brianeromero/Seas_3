import XCTest
@testable import Mat_Finder

class Mat_FinderTests: XCTestCase {

    var mat_Finder: Mat_Finder!

    override func setUp() {
        super.setUp()
        sat_Finder = Mat_Finder()
    }

    override func tearDown() {
        mat_Finder = nil
        super.tearDown()
    }

    // Test Firebase initialization
    func testFirebaseInitialization() {
        XCTAssertNotNil(FirebaseApp.app())
    }

    // Test Google Sign-In initialization
    func testGoogleSignInInitialization() {
        XCTAssertNotNil(GIDConfiguration.sharedInstance.clientID)
    }

    // Test Facebook initialization
    func testFacebookInitialization() {
        XCTAssertNotNil(ApplicationDelegate.shared)
    }

    // Test app delegate
    func testAppDelegate() {
        XCTAssertNotNil(mat_Finder)
    }

    // Test window property
    func testWindowProperty() {
        XCTAssertNotNil(mat_Finder.window)
    }
}
