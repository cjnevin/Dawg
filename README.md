# Dawg
Directed acyclic word graph in Swift

Usage:
```swift

let dawg = Dawg()
dawg.insert("car")
dawg.insert("plane")

assert(dawg.lookup("plane"))

```

Performance benchmark for inserting on a 'sowpods' file took 69.189 seconds, lookup took on: average: 0.000, relative standard deviation: 285.885%, values: [0.002727, 0.000013, 0.000006, 0.000023, 0.000012, 0.000012, 0.000011, 0.000011, 0.000011, 0.000021].

I investigated various different approaches to doing this and in the end decided to port/adapt code from https://github.com/baltavay/dawg.
