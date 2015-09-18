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

Running insert function on each line of a 'sowpods' file took:
> 69.189 seconds

Running lookup function on 3 words (10 times) took: 
> average: 0.000, relative standard deviation: 285.885%, values: [0.002727, 0.000013, 0.000006, 0.000023, 0.000012, 0.000012, 0.000011, 0.000011, 0.000011, 0.000021].

I investigated various different approaches to doing this and in the end decided to port/adapt code from https://github.com/baltavay/dawg.
