import XCTest
@testable import ResponderChain

final class ResponderChainTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(ResponderChain().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
