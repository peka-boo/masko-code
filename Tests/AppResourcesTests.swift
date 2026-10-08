import XCTest
@testable import masko_code

final class AppResourcesTests: XCTestCase {
    func testRequiredBundledResourcesAreAvailable() {
        XCTAssertNotNil(
            AppResources.url(forResource: "logo", withExtension: "png", subdirectory: "Images")
        )
        XCTAssertNotNil(
            AppResources.url(forResource: "masko", withExtension: "json", subdirectory: "Defaults")
        )
        XCTAssertNotNil(
            AppResources.url(forResource: "masko-terminal-focus", withExtension: "vsix", subdirectory: "Extensions")
        )
    }

    func testMissingResourceReturnsNilInsteadOfCrashing() {
        XCTAssertNil(
            AppResources.url(forResource: "missing-resource", withExtension: "png", subdirectory: "Images")
        )
    }
}
