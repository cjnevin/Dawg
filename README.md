# Dawg

Directed acyclic word graph in Swift

Usage:
```swift

let dawg = Dawg()
dawg.insert("car")
dawg.insert("plane")

assert(dawg.lookup("plane"))

var results = [String]()
dawg.anagramsOf("pgrormmer", length: 9, results: &results)
assert(results.contains("programmer"))

```

I investigated various different approaches to doing this and in the end decided to port/adapt code from https://github.com/baltavay/dawg and write some of my own, such as the 'anagramsOf' method.
