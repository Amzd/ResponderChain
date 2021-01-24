//
//  ResponderChain.swift
//
//  Created by Casper Zandbergen on 30/11/2020.
//  https://twitter.com/amzdme
//

import Foundation
import Combine
import SwiftUI
import Introspect

// MARK: - More SwiftUI-like type names

/// More SwiftUI-like typealias for ResponderChainReader
@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
public typealias ResponderReader = ResponderChainReader
/// More SwiftUI-like typealias for ResponderChain
@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
public typealias ResponderProxy = ResponderChain

// MARK: - Platform specifics

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
internal typealias ResponderPublisher = AnyPublisher<PlatformResponder?, Never>

#if os(macOS)
import Cocoa
public typealias PlatformWindow = NSWindow
@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
private typealias PlatformIntrospectionView = AppKitIntrospectionView
internal typealias PlatformResponder = NSResponder

extension NSWindow {
    @available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
    internal var firstResponderPublisher: ResponderPublisher {
        publisher(for: \.firstResponder).eraseToAnyPublisher()
    }
}

extension NSView {
    /// There is no swizzling needed on macOS
    fileprivate static var responderSwizzling: Void = ()
    
    fileprivate var canBecomeFirstResponder: Bool {
        return canBecomeKeyView
    }
}

#elseif os(iOS) || os(tvOS) || os(watchOS)
import UIKit
import SwizzleSwift
public typealias PlatformWindow = UIWindow
@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
private typealias PlatformIntrospectionView = UIKitIntrospectionView
internal typealias PlatformResponder = UIResponder

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension UIView {
    fileprivate static var responderSwizzling: Void = {
        Swizzle(UIView.self) {
            #selector(becomeFirstResponder) <-> #selector(becomeFirstResponder_ResponderChain)
            #selector(resignFirstResponder) <-> #selector(resignFirstResponder_ResponderChain)
        }
    }()
    
    internal var firstResponderPublisher: ResponderPublisher {
        Self._firstResponderPublisher.eraseToAnyPublisher()
    }
    
    // I assume that resignFirstResponder is always called before an object is meant to be released.
    // If that is not the case then having a CurrentValueSubject instead of PassthroughSubject will
    // cause the firstResponder to be retained until a new firstResponder is set.
    private static let _firstResponderPublisher = CurrentValueSubject<PlatformResponder?, Never>(nil)
    
    @objc open func becomeFirstResponder_ResponderChain() -> Bool {
        let result = becomeFirstResponder_ResponderChain()
        Self._firstResponderPublisher.send(self)
        return result
    }
    
    @objc open func resignFirstResponder_ResponderChain() -> Bool {
        Self._firstResponderPublisher.send(nil)
        guard Self.instancesRespond(to: #selector(UIView.resignFirstResponder_ResponderChain)) else {
            // UIAlertController somehow calls this but I can't figure out a
            // way to call an original resignFirstResponder. I haven't found
            // anything broken with just returning false here.
            return false
        }
        return resignFirstResponder_ResponderChain()
    }
}
#endif

// MARK: - View Extension

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension View {
    /// Tag the closest sibling view that can become first responder
    public func responderTag<Tag: Hashable>(_ tag: Tag) -> some View {
        inject(FindResponderSibling(tag: tag))
    }
    
    /// Creates a ResponderChainReader and attaches the ResponderChain as EnvironmentObject
    public func withResponderChainEnvironmentObject() -> some View {
        ResponderChainReader(reloadContent: .onlyInitialValue) {
            self.environmentObject($0)
        }
    }
    
    /// Creates a ResponderChainReader which writes into a ResponderChain and
    /// attaches the ResponderChain as EnvironmentObject
    public func withResponderChainEnvironmentObject(writingInto chain: ResponderChain) -> some View {
        ResponderChainReader(writingInto: chain) {
            self.environmentObject(chain)
        }
    }
}

// MARK: - Preferences

/// Found a responder view that was tagged
@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
struct FoundResponderPreferenceKey: PreferenceKey {
    static var defaultValue: [Data] { [] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
    
    struct Data: Equatable {
        var responder: PlatformView?
        var tag: AnyHashable
    }
}

/// A responder was tagged and will return in the future
@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
struct FutureResponderPreferenceKey: PreferenceKey {
    static var defaultValue: [Data] { [] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
    
    struct Data: Equatable {
        var tag: AnyHashable
    }
}

// MARK: - ResponderChainReader

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ResponderChainReader<Content: View>: View {
    public enum ReloadContent {
        /// Content closure is called when a new ResponderChain object is created AND when a published property on ResponderChain changes
        case eachChange
        /// Content closure is called only when a new ResponderChain object is created
        case onlyInitialValue
    }
    
    public var reloadContent: ReloadContent
    public var content: (ResponderChain) -> Content
    
    @State private var chain = ResponderChain()
    @State private var id = UUID()
    
    /// Creates a ResponderChainReader that writes all tagged views into a ResponderChain
    /// so you can manipulate the firstResponder. Tag views with `.responderTag(_:)`.
    ///
    /// - parameter reloadContent: How much the content should be reloaded. Default is `.eachChange`.
    ///
    public init(reloadContent: ReloadContent = .eachChange,
                @ViewBuilder content: @escaping (ResponderChain) -> Content) {
        self.reloadContent = reloadContent
        self.content = content
    }
    
    /// Use this init if you want to add the tagged responders inside
    /// this reader to a **different** ResponderChain. This is to enable using one
    /// ResponderChain for multiple windows on MacOS but you can also use
    /// this if you have two readers that are far apart but you have a way to bridge
    /// the ResponderChain.
    ///
    /// There is no point to call this with a nested reader because the only
    /// advantage of nesting a reader is that you get a local ResponderChain
    /// without tags from all over your app.
    ///
    public init(writingInto chain: ResponderChain,
                @ViewBuilder content: @escaping () -> Content) {
        self.reloadContent = .onlyInitialValue
        self.content = { _ in content() }
        self._chain = State(wrappedValue: chain)
    }
    
    public var body: some View {
        Group {
            switch reloadContent {
            case .eachChange:
                ResponderChainChangesForwarder(content: content, chain: chain)
            case .onlyInitialValue:
                content(chain)
            }
        }
        .onPreferenceChange(FoundResponderPreferenceKey.self) { preferences in
            self.chain.taggedRespondersForReader[id] = preferences
        }
        .onPreferenceChange(FutureResponderPreferenceKey.self) { preferences in
            self.chain.expectedRespondersForReader[id] = preferences
        }
    }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
fileprivate struct ResponderChainChangesForwarder<Content: View>: View {
    var content: (ResponderChain) -> Content
    @ObservedObject var chain: ResponderChain
    
    var body: some View {
        content(chain)
    }
}

// MARK: - ResponderChain

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
public class ResponderChain: ObservableObject {
    
    /// First loop: UI/NSView is added to the window and we can introspect to find it and update our state
    /// Second loop: the state update sends the new responder into the PreferenceKey to the ResponderChainReader
    public static var runloopsToWaitForRespondersToReturn = 2
    
    @Published public var firstResponder: AnyHashable? {
        didSet {
            if shouldUpdateUI {
                if isRetrying {
                    print("WARNING: You set a new firstResponder \(firstResponder.debugDescription) while ResponderChain is still retrying to set your last firstResponder \(oldValue.debugDescription) because it was expected to become available. THIS WILL RESULT IN UNDEFINED BEHAVIOUR. Use ResponderChain.afterRetrying to get a callback when ResponderChain is done.")
                }
                updateUIForNewFirstResponder(oldValue: oldValue)
            }
        }
    }
    
    public var availableResponders: Set<AnyHashable> {
        Set(taggedResponders
                .filter { $0.value.canBecomeFirstResponder }
                .map(\.key)
        )
    }
    
    /// If you set the firstResponder before the view is in the view hierarchy
    /// then ResponderChain will retry to make the view first responder
    /// when it becomes available. This function will call it's block after the
    /// ResponderChain is done retrying. At that point you can check if
    /// setting firstResponder was successful by comparing it to nil.
    public func afterRetrying(_ block: @escaping () -> Void) {
        if isRetrying {
            DispatchQueue.main.async {
                self.afterRetrying(block)
            }
        } else {
            block()
        }
    }
    
    private weak var actualFirstResponder: PlatformView?
    
    private var responderPublishers: [AnyHashable: AnyCancellable] = [:]
    private var shouldUpdateUI: Bool = true
    /// Responders that will be set in the future (In max 2 runloops)
    fileprivate var expectedRespondersForReader: [AnyHashable: [FutureResponderPreferenceKey.Data]] = [:] {
        didSet {
            expectedResponders = Set(expectedRespondersForReader.values.flatMap { $0.map(\.tag) })
        }
    }
    fileprivate var taggedRespondersForReader: [AnyHashable: [FoundResponderPreferenceKey.Data]] = [:] {
        didSet {
            let dataArray = taggedRespondersForReader.values.flatMap { $0 }
            taggedResponders = dataArray.reduce(into: [:]) {
                $0[$1.tag] = $1.responder
            }
            
            let windows = taggedRespondersForReader.values.compactMap {
                $0.first(where: { $0.responder?.window != nil })?.responder?.window
            }
            windows.forEach { window in
                attachResponderListener(to: window)
            }
        }
    }
    @Published private var taggedResponders: [AnyHashable: PlatformView] = [:]
    private var expectedResponders: Set<AnyHashable> = []
    
    private var isRetrying = false
    
    /// Made initialiser private because you need a ResponderChainReader to use
    /// ResponderChain in 2.0.0 which could be unintuative to 1.0.0 users.
    fileprivate init() {
        _ = PlatformView.responderSwizzling
    }
    
    private func attachResponderListener(to window: PlatformWindow) {
        let id = Unmanaged.passUnretained(window).toOpaque()
        guard responderPublishers[id] == nil else { return }
        let cancellable = window.firstResponderPublisher.sink(receiveValue: { [weak self] responder in
            self?.actualFirstResponder = responder as? PlatformView
            let tag = self?.responderTag(for: responder)
            self?.setFirstResponderWithoutUpdatingUI(tag)
        })
        responderPublishers[id] = cancellable
    }
    
    /// internal so tests can call it, if you copied the file; know that this is a private function
    internal func responderTag(for responder: PlatformResponder?) -> AnyHashable? {
        guard let view = responder as? PlatformView else {
            return nil
        }
        
        let possibleResponders = taggedResponders.filter {
            $0.value == view || view.isDescendant(of: $0.value)
        }

        let respondersByDistance: [AnyHashable: Int] = possibleResponders.mapValues {
            var distance = 0
            var responder: PlatformView? = $0
            while let step = responder, view.isDescendant(of: step) {
                responder = step.subviews.first(where: view.isDescendant(of:))
                distance += 1
            }
            return distance
        }
        
        return respondersByDistance.min(by: { $0.value < $1.value })?.key
    }
    
    fileprivate func setFirstResponderWithoutUpdatingUI(_ newFirstResponder: AnyHashable?) {
        guard !isRetrying else { return } // Retry will force an update after it's done
        shouldUpdateUI = false
        firstResponder = newFirstResponder
        shouldUpdateUI = true
    }
    
    private func updateUIForNewFirstResponder(oldValue: AnyHashable?,
                                               retry: Int = runloopsToWaitForRespondersToReturn) {
        assert(Thread.isMainThread && shouldUpdateUI)
        if let tag = firstResponder, tag != oldValue {
            if let responder = taggedResponders[tag] {
                print("Making first responder:", tag, responder)
                #if os(macOS)
                    #warning("TODO: Test multiple windows")
                    responder.window?.makeKey()
                    let succeeded = responder.window?.makeFirstResponder(responder) ?? false
                #elseif os(iOS) || os(tvOS)
                    let succeeded = responder.becomeFirstResponder()
                #endif
                if !succeeded {
                    firstResponder = nil
                    print("Failed to make \(tag) first responder")
                }
            } else if expectedResponders.contains(tag), retry >= 0 {
                isRetrying = true
                print("Expected to receive responder for tag \(tag), within \(retry) runloops so ResponderChain will retry to make firstResponder the next runloop")
                DispatchQueue.main.async {
                    self.isRetrying = false
                    self.updateUIForNewFirstResponder(oldValue: oldValue, retry: retry - 1)
                }
            } else {
                print("Can't find responder for tag \(tag), make sure to set a tag using `.responderTag(_:)`")
                if expectedResponders.contains(tag) {
                    print("The tag is still expected to return in the future but we ran out of loops to wait for it, you can raise ResponderChain.runloopsToWaitForRespondersToReturn to debug if it will eventually return")
                }
                firstResponder = nil
            }
        } else if firstResponder == nil {
            let previousResponder = oldValue.flatMap({ taggedResponders[$0] }) ?? actualFirstResponder
            print("Resigning first responder", oldValue ?? actualFirstResponder ?? "NO RESPONDER FOUND")
            #warning("TODO: Test resigning responder that wasn't tagged")
            #if os(macOS)
                previousResponder?.window?.endEditing(for: previousResponder)
            #elseif os(iOS) || os(tvOS)
                previousResponder?.endEditing(true)
            #endif
        } else {
            print("Tried setting the same responder so ResponderChain did not act")
        }
    }
}

// MARK: - Introspection

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
private struct FindResponderSibling<Tag: Hashable>: View {
    @EnvironmentObject var responderChain: ResponderChain
    
    var tag: Tag
    @State private var responder: PlatformView?
    /// Indicates if we're sure to find a responder in the future
    @State private var willFindResponder = true
    
    var body: some View {
        PlatformIntrospectionView(
            selector: { introspectionView in
                self.willFindResponder = false
                guard
                    let viewHost = Introspect.findViewHost(from: introspectionView),
                    let superview = viewHost.superview,
                    let entryIndex = superview.subviews.firstIndex(of: viewHost),
                    entryIndex > 0
                else {
                    return nil
                }
                
                func findResponder(in root: PlatformView) -> PlatformView? {
                    for subview in root.subviews {
                        if subview.canBecomeFirstResponder {
                            return subview
                        } else if let responder = findResponder(in: subview) {
                            return responder
                        }
                    }
                    return nil
                }
                
                for subview in superview.subviews[0..<entryIndex].reversed() {
                    if subview.canBecomeFirstResponder {
                        return subview
                    } else if let responder = findResponder(in: subview) {
                        return responder
                    }
                }
                
                return nil
            },
            customize: { responder in
                if self.responder != responder {
                    self.responder = responder
                }
            }
        )
        .background(Group {
            if let responder = responder {
                Color.clear.preference(
                    key: FoundResponderPreferenceKey.self,
                    value: [.init(responder: responder, tag: tag)]
                )
            }
        })
        .background(Group {
            if willFindResponder {
                Color.clear.preference(
                    key: FutureResponderPreferenceKey.self,
                    value: [.init(tag: tag)]
                )
            }
        })
    }
}

// MARK: - Helper

/// Allows direct comparison between an optional AnyHashable and a raw string or number
///
/// Example:
///     chain.firstResponder == "MyTextField"
///     chain.firstResponder == 5
///
public func ==<H: Hashable>(lhs: AnyHashable?, rhs: H) -> Bool {
    if let lhs = lhs {
        return lhs == AnyHashable(rhs)
    }
    return false
}

// MARK: - Deprecated

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension ResponderChain {
    @available(swift, obsoleted: 1.0, message: "Use `View.withResponderChainEnvironmentObject()` or the ResponderChainReader View inside your Views body. ResponderChain no longer cares about what window it is in.")
    public convenience init(forWindow _: PlatformWindow) {
        fatalError("Use `View.withResponderChainEnvironmentObject()` or the ResponderChainReader View inside your Views body")
    }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension View {
    @available(*, deprecated, renamed: "withResponderChainEnvironmentObject", message: "ResponderChain no longer cares about what window it is in.")
    public func withResponderChainForCurrentWindow() -> some View {
        self.withResponderChainEnvironmentObject()
    }
}
