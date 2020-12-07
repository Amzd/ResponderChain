# ResponderChain

Cross-platform first responder handling without subclassing views or making custom ViewRepresentables in SwiftUI

## Features

1. Getting the current first responder through `ResponderChain.firstResponder`
2. Setting a new first responder through `ResponderChain.firstResponder`
3. Getting tagged views available for receiveing first responder through `ResponderChain.availableResponders`

## Example

**SceneDelegate.swift**
```swift
...
let rootView = ResponderChainExample().environmentObject(ResponderChain(forWindow: window))
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
