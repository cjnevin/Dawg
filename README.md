# Dawg
![](https://reposs.herokuapp.com/?path=ChrisAU/Dawg&style=flat)
![](https://travis-ci.org/ChrisAU/Dawg.svg?branch=master)

Directed acyclic word graph in Swift

There are two different parts to this library DawgBuilder (responsible for creating structure) and Dawg (an optimised/minified reader).

The 'bin' file that is generated should be around half the size of the input file used, which makes this an excellent storage option for mobile devices with the entire SOWPODS file only being ~1.4 MB.

DawgBuilder Usage:
```swift

// Create a dawg binary file from a word list file.
assert(DawgBuilder.build(readingFrom: "~/input.txt", writingTo: "~/output.bin"))

// Create a DawgBuilder object manually, note items need to be inserted alpabetically.
let dawgBuilder = DawgBuilder()
dawgBuilder.insert("car")
dawgBuilder.insert("plane")

```

The above can be achieved using a _macOS Command Line Tool_ project following these steps:

```
1. File -> New Project -> macOS -> Command Line Tool
2. Paste the line above.
3. Put your file in ~ and call it 'input.txt'
4. Press ⌘R
5. Wait until it completes...
6. Copy 'output.txt' from ~ directory into your project
```

Dawg Usage:
```swift

// Load a binary file into a Dawg object.
let dawg = Dawg.load(from: "~/output.bin")
assert(dawg != nil)

// Returns false if the word is undefined
assert(dawg.lookup("plane"))

// Returns anagrams given a set of letters and a desired word length.
// Optionally, you may also provide fixed letters and the blank wildcard to use (defaults to ?)
assert(dawg.anagrams(withLetters: ["t", "a", "r"], wordLength: 3).contains("art"))

```

I investigated various different approaches to doing this and in the end decided to adapt some code from https://github.com/baltavay/dawg then minify it to reduce the storage space needed.
