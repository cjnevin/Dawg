# Dawg
![](https://reposs.herokuapp.com/?path=ChrisAU/Dawg)

Directed acyclic word graph in Swift

Usage:
```swift

// Create a dawg binary file from a word list file.
assert(Dawg.create("~/input.txt", outputPath: "~/output.bin"))

// Load a binary file into a Dawg object.
assert(Dawg.load("~/output.bin") != nil)

// Create a Dawg object manually, note items need to be inserted alpabetically.
let dawg = Dawg()
dawg.insert("car")
dawg.insert("plane")

// Returns false if the word is undefined
assert(dawg.lookup("plane"))

// Returns anagrams given a set of letters and a desired word length.
// Optionally, you may also provide fixed letters and the blank wildcard to use (defaults to ?)
assert(dawg.anagrams(withLetters: ["t", "a", "r"], wordLength: 3).contains("art"))

```

I investigated various different approaches to doing this and in the end decided to adapt some code from https://github.com/baltavay/dawg.
