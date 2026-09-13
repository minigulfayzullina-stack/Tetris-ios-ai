// Minimal stand-ins for the two Apple-only pieces GameState relies on.
//
// `Combine` does not exist on Linux, so this file lets the *rules* be compiled
// and tested here. It is never part of the iOS target — the real Combine is
// used on device.

protocol ObservableObject: AnyObject {}

@propertyWrapper
struct Published<Value> {
    var wrappedValue: Value

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}
