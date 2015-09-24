//
//  Dawg.swift
//  Dawg
//
//  Created by Chris Nevin on 16/09/2015.
//  Copyright © 2015 CJNevin. All rights reserved.
//

import Foundation

public func == (lhs: DawgNode, rhs: DawgNode) -> Bool {
    return lhs.description == rhs.description
}

public class DawgNode: CustomStringConvertible, Hashable {
    private static var nextId = 0
    
    typealias Edges = [Character: DawgNode]
    
    private lazy var edges = Edges()
    internal var final: Bool = false
    internal var id: Int
    var descr: String = ""
    
    internal init() {
        self.id = self.dynamicType.nextId
        self.dynamicType.nextId += 1
        updateDescription()
    }
    
    private init(withId id: Int, final: Bool, edges: Edges?) {
        self.dynamicType.nextId = max(self.dynamicType.nextId, id)
        self.id = id
        self.final = final
        if edges?.count > 0 { self.edges = edges! }
    }
    
    internal class func deserialize(serialized: NSArray, inout cached: [Int: DawgNode]) -> DawgNode {
        let id = serialized.firstObject! as! Int
        guard let cache = cached[id] else {
            var edges = Edges()
            if serialized.count == 3 {
                edges = Edges()
                if let serializedEdges = serialized.objectAtIndex(2) as? [String: NSArray] {
                    for (letter, array) in serializedEdges {
                        edges[Character(letter)] = DawgNode.deserialize(array, cached: &cached)
                    }
                }
            }
            let final = serialized.objectAtIndex(1) as! Int == 1
            let node = DawgNode(withId: id, final: final, edges: edges)
            cached[id] = node
            return node
        }
        return cache
    }
    
    internal func serialize() -> NSArray {
        let serialized = NSMutableArray()
        serialized.addObject(id)
        serialized.addObject(final ? 1 : 0)
        let serializedEdges = NSMutableDictionary()
        for (letter, node) in edges {
            serializedEdges[String(letter)] = node.serialize()
        }
        if serializedEdges.count > 0 {
            serialized.addObject(serializedEdges)
        }
        return serialized
    }
    
    private func updateDescription() {
        var arr = [final ? "1" : "0"]
        arr.appendContentsOf(edges.map({ "\($0.0)_\($0.1.id)" }))
        descr = arr.joinWithSeparator("_")
    }
    
    internal func setEdge(letter: Character, node: DawgNode) {
        edges[letter] = node
        updateDescription()
    }
    
    public var description: String {
        return descr
    }
    
    public var hashValue: Int {
        return self.description.hashValue
    }
}

public class Dawg {
    private let rootNode: DawgNode
    private var previousWord: String = ""
    private var previousChars: [Character] = []
    
    private lazy var uncheckedNodes = [(parent: DawgNode, letter: Character, child: DawgNode)]()
    private lazy var minimizedNodes = [DawgNode: DawgNode]()
    
    /// Initialize a new instance.
    public init() {
        rootNode = DawgNode()
    }
    
    /// Initialize with an existing root node, carrying over all hierarchy information.
    /// - parameter rootNode: Node to use.
    internal init(withRootNode rootNode: DawgNode) {
        self.rootNode = rootNode
    }
    
    /// Attempt to save structure to file.
    /// - parameter path: Path to write to.
    public func save(path: String) -> Bool {
        minimize(0)
        do {
            let data = try NSJSONSerialization.dataWithJSONObject(rootNode.serialize(), options: NSJSONWritingOptions.init(rawValue: 0))
            data.writeToFile(path, atomically: true)
            return true
        }
        catch {
            return false
        }
    }
    
    /// Attempt to load structure from file.
    /// - parameter path: Path of file to read.
    /// - returns: New Dawg with initialized rootNode or nil.
    public class func load(path: String) -> Dawg? {
        guard let stream = NSInputStream(fileAtPath: path) else { return nil }
        defer {
            stream.close()
        }
        stream.open()
        do {
            guard let contents = try NSJSONSerialization.JSONObjectWithStream(stream,
                options: NSJSONReadingOptions.AllowFragments) as? NSArray else { return nil }
            var cache = [Int: DawgNode]()
            return Dawg(withRootNode: DawgNode.deserialize(contents, cached: &cache))
        } catch {
            return nil
        }
    }
    
    /// Replace redundant nodes in uncheckedNodes with ones existing in minimizedNodes
    /// then truncate.
    /// - parameter downTo: Iterate from count to this number (truncates these items).
    public func minimize(downTo: Int) {
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
    /// - parameter word: Word to insert.
    public func insert(word: String) {
        assert(previousWord == "" || (previousWord != "" && previousWord < word))
        
        // Find common prefix for word and previous word.
        let chars = Array(word.characters)
        var commonPrefix = 0
        for i in 0..<min(chars.count, previousChars.count) {
            if chars[i] != previousChars[i] { break }
            commonPrefix++
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
        
        previousWord = word
        previousChars = chars
        node.final = true
    }
    
    /// - parameter word: Word to check.
    /// - returns: True if the word exists.
    public func lookup(word: String) -> Bool {
        var node = rootNode
        for letter in word.lowercaseString.characters {
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
    ///     - length: Length of word to return.
    ///     - prefix: (Optional) Letters of current result already realised.
    ///     - fixedLetters: (Optional) Letters that are already filled at given positions.
    ///     - fixedCount: (Ignore) Number of fixed letters, recalculated by method.
    ///     - root: Node in the Dawg tree we are currently using.
    ///     - blankLetter: (Optional) Letter to use instead of ?.
    /// - returns: Array of possible words.
    public func anagramsOf(letters: [Character],
        length: Int,
        prefix: [Character]? = nil,
        filledLetters: [Int: Character]? = nil,
        filledCount: Int? = nil,
        root: DawgNode? = nil,
        blankLetter: Character = "?",
        inout results: [String])
    {
        // Realise any fields that are empty on first run.
        let _prefix = prefix ?? [Character]()
        let _prefixLength = _prefix.count
        var _filled = filledLetters ?? [Int: Character]()
        let _numFilled = filledCount ?? _filled.count
        let _source = root ?? rootNode
        
        // See if position exists in filled array.
        if let letter = _filled[_prefixLength],
            newSource = _source.edges[letter]
        {
            // Add letter to prefix
            var newPrefix = _prefix
            newPrefix.append(letter)
            _filled.removeValueForKey(_prefixLength)
            // Recurse with new prefix/letters
            anagramsOf(letters,
                length: length,
                prefix: newPrefix,
                filledLetters: _filled,
                filledCount: _numFilled,
                root: newSource,
                results: &results)
            return
        }
        
        // Check if the current prefix is actually a word.
        if _source.final &&
            _filled.count == 0 &&
            _prefixLength == length &&
            _prefixLength > _numFilled
        {
            results.append(String(_prefix))
        }
        
        // Check each edge of this node to see if any of the letters
        // exist in our rack letters (or we have a '?').
        _source.edges.forEach { (letter, node) in
            if let index = letters.indexOf(letter) ?? letters.indexOf(blankLetter) {
                // Copy letters, removing this letter
                var newLetters = letters
                newLetters.removeAtIndex(index)
                // Add letter to prefix
                var newPrefix = _prefix
                newPrefix.append(letter)
                // Recurse with new prefix/letters
                anagramsOf(newLetters,
                    length: length,
                    prefix: newPrefix,
                    filledLetters: _filled,
                    filledCount: _numFilled,
                    root: node,
                    results: &results)
            }
        }
    }
}