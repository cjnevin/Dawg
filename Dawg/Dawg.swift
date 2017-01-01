//
//  Dawg.swift
//  Dawg
//
//  Created by Chris Nevin on 25/06/2016.
//  Copyright © 2016 CJNevin. All rights reserved.
//

import Foundation

private let uint32Size = MemoryLayout<UInt32>.size
private let uint8Size = MemoryLayout<UInt8>.size
private let onUInt8 = UInt8(1)
private let offUInt8 = UInt8(0)

typealias DawgLetter = UInt8
private typealias Edges = [DawgLetter: Int]

class DataBuffer {
    fileprivate let data: Data
    fileprivate var offset: Int = 0
    /// Create a data buffer with a data.
    init(_ data: Data) {
        self.data = data
    }
    
    /// Extract a value of requested type and shift offset forward by size.
    fileprivate func get<T: UnsignedInteger>(_ size: Int) -> T {
        // sizeof is too slow to be performed in bulk, which is why it is
        // only run once at top of file.
        var value: T = 0
        (data as NSData).getBytes(&value, range: NSMakeRange(offset, size))
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
    func append<T: Integer>(_ value: T, size: Int? = nil) {
        var bytes = value
        self.append(&bytes, length: size ?? MemoryLayout<T>.size)
    }
}

private struct Node: Hashable {
    static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

    let edges: Edges
    let final: Bool
    let id: Int
    fileprivate var hashValue: Int {
        return id
    }
}

open class Dawg {
    
    fileprivate subscript(id: Int) -> Node {
        return sortedNodes[id]
    }
    
    fileprivate let sortedNodes: [Node]
    fileprivate let rootNode: Node
    
    /// - returns: Serialized nodes in NSData format.
    func serialize() -> Data {
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
        return buffer as Data
    }
    
    /// Attempt to load structure from file.
    /// - parameter path: Path of file to read.
    /// - returns: New Dawg with initialized rootNode or nil.
    open class func load(from path: String) -> Dawg? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return deserialize(data: DataBuffer(data))
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
    
    fileprivate init?(nodes: [Node]) {
        guard let first = nodes.first else {
            return nil
        }
        sortedNodes = nodes
        rootNode = first
    }
    
    init(root: DawgBuilderNode) {
        // Build temporary structure for mapping below
        var temp = [Int: Node]()
        func addNode(_ newNode: DawgBuilderNode) {
            var leanEdges = [DawgLetter: Int]()
            newNode.edges.forEach { (letter, node) in
                leanEdges[letter] = Int(node.id)
                addNode(node)
            }
            temp[Int(newNode.id)] = Node(edges: leanEdges, final: newNode.final, id: Int(newNode.id))
        }
        addNode(root)
        
        // Sort then map id to index
        let lookup = temp.keys.sorted()
        var replacement = [Int: Int]()
        lookup.enumerated().forEach { (index, id) in
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
        sortedNodes = fixed.sorted(by: { $0.id < $1.id })
        for (index, node) in sortedNodes.enumerated() {
            assert(index == Int(node.id))
        }
        rootNode = sortedNodes.first!
    }
    
    open func lookup(_ word: String) -> Bool {
        var node = rootNode
        for letter in word.lowercased().utf8 {
            guard let edgeNode = node.edges[letter] else { return false }
            node = self[edgeNode]
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
    fileprivate func recursiveAnagrams(
        withLetters letters: [DawgLetter],
                    wordLength: Int,
                    prefix: [DawgLetter],
                    filled: [Int: DawgLetter],
                    filledCount: Int,
                    source: Node,
                    blankLetter: DawgLetter = "?".utf8.first!,
                    results: inout [String])
    {
        // See if position exists in filled array.
        if let letter = filled[prefix.count],
            let newSource = source.edges[letter]
        {
            // Add letter to prefix
            var newFilled = filled
            var newPrefix = prefix
            newPrefix.append(letter)
            newFilled.removeValue(forKey: prefix.count)
            // Recurse with new prefix/letters
            recursiveAnagrams(withLetters: letters,
                              wordLength: wordLength, prefix: newPrefix,
                              filled: newFilled, filledCount: filledCount,
                              source: self[newSource], blankLetter: blankLetter,
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
            if let word = String(bytesNoCopy: &bytes, length: prefix.count, encoding: String.Encoding.utf8, freeWhenDone: false) {
                results.append(word)
            }
        }
        
        // Check each edge of this node to see if any of the letters
        // exist in our rack letters (or we have a '?').
        source.edges.forEach { (letter, node) in
            //print(letter, letters, String(letter), letters.map({ String($0) }))
            if let index = letters.index(of: letter) ?? letters.index(of: blankLetter) {
                // Copy letters, removing this letter
                var newLetters = letters
                newLetters.remove(at: index)
                // Add letter to prefix
                var newPrefix = prefix
                newPrefix.append(letter)
                // Recurse with new prefix/letters
                recursiveAnagrams(withLetters: newLetters,
                    wordLength: wordLength, prefix: newPrefix,
                    filled: filled, filledCount: filledCount,
                    source: self[node], blankLetter: blankLetter,
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
    open func anagrams(
        withLetters letters: [Character],
                    wordLength: Int,
                    filledLetters: [Int: Character] = [Int: Character](),
                    blankLetter: Character = "?") -> [String]?
    {
        var filled = [Int: DawgLetter]()
        for (key, value) in filledLetters {
            filled[key] = String(value).lowercased().utf8.first!
        }
        var results = [String]()
        recursiveAnagrams(withLetters: letters.map({ String($0).lowercased().utf8.first! }),
                          wordLength: wordLength, prefix: [DawgLetter](), filled: filled,
                          filledCount: filled.count, source: rootNode,
                          blankLetter: String(blankLetter).utf8.first!, results: &results)
        return results.count > 0 ? results : nil
    }
}
