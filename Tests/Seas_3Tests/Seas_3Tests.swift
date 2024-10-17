import XCTest
@testable import Seas_3

class Seas_3Tests: XCTestCase {

    var seas_3: Seas_3!

    override func setUp() {
        super.setUp()
        seas_3 = Seas_3()
    }

    override func tearDown() {
        seas_3 = nil
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
        XCTAssertNotNil(seas_3)
    }

    // Test window property
    func testWindowProperty() {
        XCTAssertNotNil(seas_3.window)
    }
}
