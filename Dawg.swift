//
//  Dawg.swift
//  Dawg
//
//  Created by Chris Nevin on 25/05/2016.
//  Copyright © 2016 CJNevin. All rights reserved.
//

import Foundation

private let uint32Size = sizeof(UInt32)
private let uint8Size = sizeof(UInt8)
private let onUInt8 = UInt8(1)
private let offUInt8 = UInt8(0)

typealias DawgLetter = UInt8
private typealias Edges = [DawgLetter: Int]

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

private func == (lhs: Node, rhs: Node) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

private struct Node: Hashable {
    let edges: Edges
    let final: Bool
    let id: Int
    private var hashValue: Int {
        return id
    }
}

public class Dawg {
    
    private let indexedNodes: [Int: Node]
    private let sortedNodes: [Node]
    private let rootNode: Node
    
    /// - returns: Serialized nodes in NSData format.
    func serialize() -> NSData {
        let buffer = NSMutableData()
        buffer.append(sortedNodes.count, size: uint32Size)
        for current in sortedNodes {
            buffer.append(current.final ? onUInt8 : offUInt8, size: uint8Size)
            buffer.append(current.id, size: uint32Size)
            buffer.append(UInt8(current.edges.count), size: uint8Size)
            for (letter, node) in current.edges {
                buffer.append(letter, size: uint8Size)
                buffer.append(UInt32(node), size: uint32Size)
            }
        }
        return buffer
    }
    
    /// Attempt to load structure from file.
    /// - parameter path: Path of file to read.
    /// - returns: New Dawg with initialized rootNode or nil.
    public class func load(path: String) -> Dawg? {
        guard let data = NSData(contentsOfFile: path) else { return nil }
        return deserialize(DataBuffer(data))
    }
    
    /// Deserialize data, creating node hierarchy.
    /// - parameter data: Buffer instance that handles deserializing data.
    /// - returns: Dawg instance.
    class func deserialize(data: DataBuffer) -> Dawg? {
        let nodeCount = Int(data.getUInt32())
        var cached = [Node]()
        for _ in 0..<nodeCount {
            let (final, id, edgeCount) = (data.getUInt8(), data.getUInt32(), data.getUInt8())
            var edges = [DawgLetter: Int]()
            for _ in 0..<edgeCount {
                edges[data.getUInt8()] = Int(data.getUInt32())
            }
            cached.append(Node(edges: edges, final: final == onUInt8, id: Int(id)))
        }
        return Dawg(nodes: cached)
    }
    
    private init?(nodes: [Node]) {
        guard let first = nodes.first else {
            return nil
        }
        sortedNodes = nodes
        var hashed = [Int: Node]()
        nodes.forEach { (node) in
            hashed[node.id] = node
        }
        indexedNodes = hashed
        rootNode = first
    }
    
    init(root: DawgBuilderNode) {
        // Build temporary structure for mapping below
        var temp = [Int: Node]()
        func addNode(current: DawgBuilderNode) {
            var leanEdges = [DawgLetter: Int]()
            current.edges.forEach { (letter, node) in
                leanEdges[letter] = Int(node.id)
                addNode(node)
            }
            temp[Int(current.id)] = Node(edges: leanEdges, final: current.final, id: Int(current.id))
        }
        addNode(root)
        
        // Sort then map id to index
        let lookup = temp.keys.sort()
        var replacement = [Int: Int]()
        lookup.enumerate().forEach { (index, id) in
            replacement[id] = index
        }
        
        // Replace id's with indexes
        let fixed = temp.values.map { (node) -> Node in
            let newID = replacement[node.id]!
            var newEdges = [DawgLetter: Int]()
            node.edges.forEach({ (letter, id) in
                newEdges[letter] = replacement[id]!
            })
            return Node(edges: newEdges, final: node.final, id: newID)
        }
        
        // Sort by index and ensure no gaps
        sortedNodes = fixed.sort({ $0.id < $1.id })
        for (index, node) in sortedNodes.enumerate() {
            assert(index == Int(node.id))
        }
        
        var hashed = [Int: Node]()
        sortedNodes.forEach { (node) in
            hashed[node.id] = node
        }
        indexedNodes = hashed
        rootNode = sortedNodes.first!
    }
    
    public func lookup(word: String) -> Bool {
        var node = rootNode
        for letter in word.lowercaseString.utf8 {
            guard let edgeNode = node.edges[letter] else { return false }
            node = indexedNodes[edgeNode]!
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
                    source: Node,
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
                              source: indexedNodes[newSource]!, blankLetter: blankLetter,
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
                    source: indexedNodes[node]!, blankLetter: blankLetter,
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
