//
//  Dawg.swift
//  Dawg
//
//  Created by Chris Nevin on 16/09/2015.
//  Copyright © 2015 CJNevin. All rights reserved.
//

import Foundation

private let uint32Size = sizeof(UInt32)
private let uint8Size = sizeof(UInt8)
private let onUInt8 = UInt8(1)
private let offUInt8 = UInt8(0)
private let onText = "0"
private let offText = "1"
private let edgeSeparator: String = "_"

class DataBuffer {
    private let data: NSData
    private var offset: Int = 0
    /// Create a data buffer with a data.
    init(_ data: NSData) {
        self.data = data
    }
    
    /// Extract a value of requested type and shift offset forward by size.
    private func get<T: UnsignedIntegerType>(size: Int) -> T {
        // sizeof is too slow to be performed in bulk, which is why it is
        // only run once at top of file.
        var value: T = 0
        data.getBytes(&value, range: NSMakeRange(offset, size))
        offset += size
        return value
    }
    
    /// Extract a UInt8 then move offset forward by 1.
    func getUInt8() -> UInt8 {
        return get(uint8Size)
    }
    
    /// Extract a UInt32 then move offset forward by 4.
    func getUInt32() -> UInt32 {
        return get(uint32Size)
    }
}

private extension NSMutableData {
    func append<T: IntegerType>(value: T, size: Int? = nil) {
        var bytes = value
        appendBytes(&bytes, length: size ?? sizeof(value.dynamicType))
    }
}

typealias DawgLetter = UInt8

func == (lhs: DawgNode, rhs: DawgNode) -> Bool {
    return lhs.descr == rhs.descr
}

class DawgNode: CustomStringConvertible, Hashable {
    typealias Edges = [DawgLetter: DawgNode]
    
    private static var nextId: UInt32 = 0
    private var descr: String = ""
    lazy var edges = Edges()
    var final: Bool = false
    var id: UInt32
    
    /// Create a new node while building a new Dawg.
    init() {
        self.id = self.dynamicType.nextId
        self.dynamicType.nextId += 1
        updateDescription()
    }
    
    /// Create a new node with existing data into an existing Dawg.
    /// - parameter id: Node identifier.
    /// - parameter final: Whether this node terminates a word.
    init(withId id: UInt32, final: Bool) {
        self.dynamicType.nextId = max(self.dynamicType.nextId, id)
        self.id = id
        self.final = final
    }
    
    /// Helper function to create a new node and add it to cache.
    private class func newNode(withId id: UInt32, final: Bool, inout cached: [UInt32: DawgNode]) -> DawgNode {
        let node = DawgNode(withId: id, final: final)
        cached[id] = node
        return node
    }
    
    /// Deserialize data, creating node hierarchy.
    /// - parameter data: Buffer instance that handles deserializing data.
    /// - parameter cached: Cache used for minifying nodes.
    /// - returns: Returns root node.
    class func deserialize(data: DataBuffer, inout cached: [UInt32: DawgNode]) -> DawgNode {
        let (final, id, count) = (data.getUInt8(), data.getUInt32(), data.getUInt8())
        let node = cached[id] ?? newNode(withId: id, final: final == 1, cached: &cached)
        for _ in 0..<count {
            node.edges[data.getUInt8()] = deserialize(data, cached: &cached)
        }
        return node
    }
    
    /// Appends to buffer with data for current node and it's edges.
    private func serialize(inout buffer: NSMutableData) {
        buffer.append(final ? onUInt8 : offUInt8, size: uint8Size)
        buffer.append(id, size: uint32Size)
        buffer.append(UInt8(edges.count), size: uint8Size)
        for (letter, node) in edges {
            buffer.append(letter, size: uint8Size)
            node.serialize(&buffer)
        }
    }
    
    /// - returns: Serialized data for storage.
    func serialized() -> NSData {
        var buffer = NSMutableData()
        serialize(&buffer)
        return buffer.copy() as! NSData
    }
    
    func updateDescription() {
        descr = final ? offText : onText + edgeSeparator + edges.map({ "\($0.0)\(edgeSeparator)\($0.1.id)" }).joinWithSeparator(edgeSeparator)
    }
    
    func setEdge(letter: DawgLetter, node: DawgNode) {
        edges[letter] = node
        updateDescription()
    }
    
    var description: String {
        return descr
    }
    
    var hashValue: Int {
        return descr.hashValue
    }
}

public class Dawg {
    private var finalized: Bool = false
    internal let rootNode: DawgNode
    private var previousChars: [UInt8] = []
    private lazy var uncheckedNodes = [(parent: DawgNode, letter: DawgLetter, child: DawgNode)]()
    private lazy var minimizedNodes = [DawgNode: DawgNode]()
    
    /// Initialize a new instance.
    public init() {
        rootNode = DawgNode()
    }
    
    /// Initialize with an existing root node, carrying over all hierarchy information.
    /// - parameter rootNode: Node to use.
    private init(withRootNode rootNode: DawgNode) {
        self.rootNode = rootNode
        finalized = true
    }
    
    /// Attempt to create a Dawg structure from a file.
    /// - parameter inputPath: Path to load wordlist from.
    /// - parameter outputPath: Path to write binary Dawg file to.
    public class func create(inputPath: String, outputPath: String) -> Bool {
        do {
            let data = try String(contentsOfFile: inputPath, encoding: NSUTF8StringEncoding)
            let dawg = Dawg()
            let characters = Array(data.utf8)
            let newLine = "\n".utf8.first!
            var buffer = [UInt8]()
            var i = 0
            repeat {
                var char = characters[i]
                while char != newLine
                {
                    buffer.append(char)
                    i += 1
                    if i >= characters.count { break }
                    char = characters[i]
                }
                dawg.insert(buffer)
                buffer.removeAll()
                i += 1
            } while i != characters.count
            dawg.minimize(0)
            dawg.save(outputPath)
            return true
        } catch {
            return false
        }
    }
    
    /// Attempt to save structure to file.
    /// - parameter path: Path to write to.
    private func save(path: String) -> Bool {
        return rootNode.serialized().writeToFile(path, atomically: true)
    }
    
    /// Attempt to load structure from file.
    /// - parameter path: Path of file to read.
    /// - returns: New Dawg with initialized rootNode or nil.
    public class func load(path: String) -> Dawg? {
        guard let data = NSData(contentsOfFile: path) else { return nil }
        var cache = [UInt32: DawgNode]()
        return Dawg(withRootNode: DawgNode.deserialize(DataBuffer(data), cached: &cache))
    }
    
    /// Replace redundant nodes in uncheckedNodes with ones existing in minimizedNodes
    /// then truncate.
    /// - parameter downTo: Iterate from count to this number (truncates these items).
    private func minimize(downTo: Int) {
        for i in (downTo..<uncheckedNodes.count).reverse() {
            let (parent, letter, child) = uncheckedNodes[i]
            if let node = minimizedNodes[child] {
                parent.setEdge(letter, node: node)
            } else {
                minimizedNodes[child] = child
            }
            uncheckedNodes.popLast()
        }
    }
    
    /// Insert a word into the graph, words must be inserted in order.
    /// - parameter chars: UInt8 array.
    private func insert(chars: [UInt8]) -> Bool {
        if finalized { return false }
        var commonPrefix = 0
        for i in 0..<min(chars.count, previousChars.count) {
            if chars[i] != previousChars[i] { break }
            commonPrefix += 1
        }
        
        // Minimize nodes before continuing.
        minimize(commonPrefix)
        
        var node: DawgNode
        if uncheckedNodes.count == 0 {
            node = rootNode
        } else {
            node = uncheckedNodes.last!.child
        }
        
        // Add the suffix, starting from the correct node mid-way through the graph.
        //var node = uncheckedNodes.last?.child ?? rootNode
        chars[commonPrefix..<chars.count].forEach {
            let nextNode = DawgNode()
            node.setEdge($0, node: nextNode)
            uncheckedNodes.append((node, $0, nextNode))
            node = nextNode
        }
        
        previousChars = chars
        node.final = true
        return true
    }
    
    /// Insert a word into the graph, words must be inserted in order.
    /// - parameter word: Word to insert.
    public func insert(word: String) -> Bool {
        return insert(Array(word.utf8))
    }
    
    /// - parameter word: Word to check.
    /// - returns: True if the word exists.
    public func lookup(word: String) -> Bool {
        var node = rootNode
        for letter in word.lowercaseString.utf8 {
            guard let edgeNode = node.edges[letter] else { return false }
            node = edgeNode
        }
        return node.final
    }
    
    /// Calculates all possible words given a set of rack letters
    /// optionally providing fixed letters which can be used
    /// to indicate that these positions are already filled.
    /// - parameters:
    ///     - letters: Letter in rack to use.
    ///     - wordLength: Length of word to return.
    ///     - prefix: (Optional) Letters of current result already realised.
    ///     - filled: (Optional) Letters that are already filled at given positions.
    ///     - filledCount: (Ignore) Number of fixed letters, recalculated by method.
    ///     - source: (Optional) Node in the Dawg tree we are currently using.
    ///     - blankLetter: (Optional) Letter to use instead of ?.
    ///     - results: Array of possible words.
    private func recursiveAnagrams(
        withLetters letters: [DawgLetter],
        wordLength: Int,
        prefix: [DawgLetter],
        filled: [Int: DawgLetter],
        filledCount: Int,
        source: DawgNode,
        blankLetter: DawgLetter = "?".utf8.first!,
        inout results: [String])
    {
        // See if position exists in filled array.
        if let letter = filled[prefix.count],
            newSource = source.edges[letter]
        {
            // Add letter to prefix
            var newFilled = filled
            var newPrefix = prefix
            newPrefix.append(letter)
            newFilled.removeValueForKey(prefix.count)
            // Recurse with new prefix/letters
            recursiveAnagrams(withLetters: letters,
                wordLength: wordLength, prefix: newPrefix,
                filled: newFilled, filledCount: filledCount,
                source: newSource, blankLetter: blankLetter,
                results: &results)
            return
        }
        
        // Check if the current prefix is actually a word.
        if source.final &&
            filled.count == 0 &&
            prefix.count == wordLength &&
            prefix.count > filledCount
        {
            var bytes = prefix
            if let word = String(bytesNoCopy: &bytes, length: prefix.count, encoding: NSUTF8StringEncoding, freeWhenDone: false) {
                results.append(word)
            }
        }
        
        // Check each edge of this node to see if any of the letters
        // exist in our rack letters (or we have a '?').
        source.edges.forEach { (letter, node) in
            //print(letter, letters, String(letter), letters.map({ String($0) }))
            if let index = letters.indexOf(letter) ?? letters.indexOf(blankLetter) {
                // Copy letters, removing this letter
                var newLetters = letters
                newLetters.removeAtIndex(index)
                // Add letter to prefix
                var newPrefix = prefix
                newPrefix.append(letter)
                // Recurse with new prefix/letters
                recursiveAnagrams(withLetters: newLetters,
                    wordLength: wordLength, prefix: newPrefix,
                    filled: filled, filledCount: filledCount,
                    source: node, blankLetter: blankLetter,
                    results: &results)
            }
        }
    }
    
    /// Calculates all possible words given a set of rack letters
    /// optionally providing fixed letters which can be used
    /// to indicate that these positions are already filled.
    /// - parameters:
    ///     - letters: Letter in rack to use.
    ///     - wordLength: Length of word to return.
    ///     - filledLetters: (Optional) Letters that are already filled at given positions.
    ///     - blankLetter: (Optional) Letter to use instead of ?.
    /// - returns: Array of possible words.
    public func anagrams(
        withLetters letters: [Character],
        wordLength: Int,
        filledLetters: [Int: Character] = [Int: Character](),
        blankLetter: Character = "?") -> [String]?
    {
        var filled = [Int: DawgLetter]()
        for (key, value) in filledLetters {
            filled[key] = String(value).lowercaseString.utf8.first!
        }
        var results = [String]()
        recursiveAnagrams(withLetters: letters.map({ String($0).lowercaseString.utf8.first! }),
            wordLength: wordLength, prefix: [DawgLetter](), filled: filled,
            filledCount: filled.count, source: rootNode,
            blankLetter: String(blankLetter).utf8.first!, results: &results)
        return results.count > 0 ? results : nil
    }
}