# Dawg

Directed acyclic word graph in Swift

Usage:
```swift

// Create a dawg binary file from a word list file.
assert(dawg.create("~/input.txt", outputPath: "~/output.bin"))

// Load a binary file into a Dawg object.
assert(Dawg.load("~/output.bin") != nil)

// Create a Dawg object manually, note items need to be inserted alpabetically.
let dawg = Dawg()
dawg.insert("car")
dawg.insert("plane")

// Returns false if the word is undefined
assert(dawg.lookup("plane"))

```

I investigated various different approaches to doing this and in the end decided to adapt some code from https://github.com/baltavay/dawg.
