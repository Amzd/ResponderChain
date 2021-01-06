import XCTest
import ViewInspector
import SwiftUI
import Combine
@testable import ResponderChain

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
struct ResponderChainExample: View, Inspectable {
    @ObservedObject var chain: ResponderChain
    
    var body: some View {
        VStack(spacing: 20) {
            // Show which view is first responder
            Text("Selected field: \(chain.firstResponder?.description ?? "Nothing selected")")
            
            // Some views that can become first responder
            TextField("0", text: .constant(""), onCommit: { chain.firstResponder = "1" }).responderTag("0")
            TextField("1", text: .constant(""), onCommit: { chain.firstResponder = "2" }).responderTag("1")
            TextField("2", text: .constant(""), onCommit: { chain.firstResponder = "3" }).responderTag("2")
            TextField("3", text: .constant(""), onCommit: { chain.firstResponder = nil }).responderTag("3")
            
            // Buttons to change first responder
            HStack {
                Button("Select 0", action: { chain.firstResponder = "0" })
                Button("Select 1", action: { chain.firstResponder = "1" })
                Button("Select 2", action: { chain.firstResponder = "2" })
                Button("Select 3", action: { chain.firstResponder = "3" })
                Button("Select Nothing", action: { chain.firstResponder = nil })
            }
        }
        .environmentObject(chain)
        .padding()
        .onAppear {
            // Set first responder on appear
            DispatchQueue.main.async {
                chain.firstResponder = "0"
            }
        }
    }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
final class ResponderChainTests: XCTestCase {
    static var chain: ResponderChain!
    static var window: PlatformWindow!
    
    override func setUp() {
        super.setUp()
        if Self.chain == nil {
            let didSetResponderChain = XCTestExpectation(description: "Did set ResponderChain")
            let windowGrabber = EmptyView().introspect(selector: { $0.self }) {
                if let window = $0.window {
                    Self.chain = ResponderChain(forWindow: window)
                    Self.window = window
                    didSetResponderChain.fulfill()
                }
            }
            ViewHosting.host(view: windowGrabber)
            wait(for: [didSetResponderChain], timeout: 0.1)
        }
        
        // Every test gets a new view
        testView = ResponderChainExample(chain: Self.chain)
        ViewHosting.host(view: testView, viewId: "ResponderChain")
    }
    override func tearDown() {
        super.tearDown()
        ViewHosting.expel(viewId: "ResponderChain")
    }
    
    var cancellables: Set<AnyCancellable> = []
    var testView: ResponderChainExample!
    
    func didSetFirstResponder(to tag: AnyHashable?) -> XCTestExpectation {
        let didSetFirstResponder = XCTestExpectation(description: "Did set ResponderChain.firstResponder and did not fail")
        didSetFirstResponder.expectedFulfillmentCount = 2
        
        Self.chain.$firstResponder.first(where: { $0 == tag }).sink { newFirstResponder in
            DispatchQueue.main.async {
                // If setting the firstResponder failed, chain.firstResponder will be nil here
                if Self.chain.firstResponder == newFirstResponder {
                    didSetFirstResponder.fulfill()
                }
            }
        }.store(in: &self.cancellables)
        
        Self.window.firstResponderPublisher.first(where: { Self.chain.responderTag(for: $0) == tag }).sink { view in
            DispatchQueue.main.async {
                // If setting the firstResponder failed, chain.firstResponder will be nil here
                if Self.chain.firstResponder == Self.chain.responderTag(for: view) {
                    didSetFirstResponder.fulfill()
                }
            }
        }.store(in: &self.cancellables)
        
        return didSetFirstResponder
    }
    
    func testAll() throws {
        wait(for: [didSetFirstResponder(to: "0")], timeout: 0.5)
        XCTAssert(try testView.inspect().find(ViewType.Text.self).string() == "Selected field: 0")
        
        try testView.inspect().findAll(ViewType.TextField.self)[0].callOnCommit()
        wait(for: [didSetFirstResponder(to: "1")], timeout: 0.5)
        XCTAssert(try testView.inspect().find(ViewType.Text.self).string() == "Selected field: 1")
        
        try testView.inspect().findAll(ViewType.Button.self)[2].tap()
        wait(for: [didSetFirstResponder(to: "2")], timeout: 0.5)
        XCTAssert(try testView.inspect().find(ViewType.Text.self).string() == "Selected field: 2")
        
        try testView.inspect().findAll(ViewType.Button.self)[4].tap()
        wait(for: [didSetFirstResponder(to: nil)], timeout: 0.5)
        XCTAssert(try testView.inspect().find(ViewType.Text.self).string() == "Selected field: Nothing selected")
        
        Self.chain.firstResponder = "1"
        XCTAssert(Self.chain.firstResponder == "1")
        Self.chain.firstResponder = "Something that isn't tagged"
        XCTAssert(Self.chain.firstResponder == nil)
        
        XCTAssert(Set(Self.chain.availableResponders) == ["0", "1", "2", "3"])
    }

    static var allTests = [
        ("testAll", testAll),
    ]
}
