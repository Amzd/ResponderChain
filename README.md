As of June 7 2021 this functionality is in the SwiftUI 3 beta. https://developer.apple.com/documentation/SwiftUI/FocusState

The Apple implementation is a bit different from ResponderChain but switching over looks to be quite easy.

Also the Apple implementation only supports iOS 15 so I think this repo is still useful for backwards compatibility.

# ⛓️ ResponderChain

Cross-platform first responder handling without subclassing views or making custom ViewRepresentables in SwiftUI

## Features

- **💡 Easy to use:** Get, set and resign first responder simply through an EnvironmentObject.
- **⏰ Time Saving:** If an underlying view can become first responder all you have to do is tag it; and it works!
- **👀 Insightful:** Gives insight in which views can become first responder.

## Overview

Attach the ResponderChain as environmentObject.

```swift
// In the SceneDelegate or ApplicationDelegate where you have access to the window:
let rootView = Example().environmentObject(ResponderChain(forWindow: window))

// SwiftUI only:
Example().withResponderChainForCurrentWindow()
```

Tag views that can become first responder.

```swift
TextField(...).responderTag("MyTextField")
```

Check tagged views that are currently available to become first responder.

```swift
chain.availableResponders.contains("MyList")
```

Make tagged views become first responder.

```swift
chain.firstResponder = "MyTextField"
if chain.firstResponder == nil {
    print("Failed")
}
```
> This is completely safe, if "MyTextField" was either not available to become first responder or it wasn't tagged properly; `chain.firstResponder` will become `nil`



Resign first responder.

```swift
chain.firstResponder = nil
```
> **Note:** This only works if the current firstResponder was tagged.

## Example

Attach the ResponderChain as environmentObject.

```swift
...
// In the SceneDelegate or ApplicationDelegate where you have access to the window:
let rootView = ResponderChainExample().environmentObject(ResponderChain(forWindow: window))

// SwiftUI only:
ResponderChainExample().withResponderChainForCurrentWindow()
...
```

**ResponderChainExample.swift**
```swift
struct ResponderChainExample: View {
    @EnvironmentObject var chain: ResponderChain
    
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
            }
        }
        .padding()
        .onAppear {
            // Set first responder on appear
            DispatchQueue.main.async {
                chain.firstResponder = "0"
            }
        }
    }
}
```

<img src="ChainResponder.gif" width="300">
