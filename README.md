# Dawg

![](https://reposs.herokuapp.com/?path=ChrisAU/Dawg)

Directed acyclic word graph in Swift

Usage:
```swift

let dawg = Dawg()
dawg.insert("car")
dawg.insert("plane")

assert(dawg.lookup("plane"))

```

I investigated various different approaches to doing this and in the end decided to port/adapt code from https://github.com/baltavay/dawg.
