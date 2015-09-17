# Dawg
Directed acyclic word graph in Swift

Usage:
```swift

let dawg = Dawg()
dawg.insert("car")
dawg.insert("plane")

assert(dawg.lookup("plane"))

```

Performance benchmark on a 'sowpods' file took 69.189 seconds.

I investigated various different approaches to doing this and in the end decided to port/adapt code from https://github.com/baltavay/dawg.
