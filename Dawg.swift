//
//  Dawg.swift
//  Dawg
//
//  Created by Chris Nevin on 16/09/2015.
//  Copyright © 2015 CJNevin. All rights reserved.
//

import Foundation

func == (lhs: DawgNode, rhs: DawgNode) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

class DawgNode: CustomStringConvertible, Hashable {
    static var nextId = 0;
    
    typealias Edges = [Character: DawgNode]
    
    lazy var edges = Edges()
    var final: Bool = false
    var id: Int
    var descr: String = ""
    
    init() {
        self.id = self.dynamicType.nextId
        self.dynamicType.nextId += 1
        updateDescription()
    }
    
    private init(withId id: Int, final: Bool, edges: Edges?) {
        self.id = id
        self.final = final
        if edges?.count > 0 { self.edges = edges! }
        updateDescription()
    }
    
    class func deserialize(serialized: NSArray, inout cached: [Int: DawgNode]) -> DawgNode {
        let id = serialized.firstObject! as! Int
        guard let cache = cached[id] else {
            var edges: Edges?
            if serialized.count == 3 {
                edges = Edges()
                if let serializedEdges = serialized.objectAtIndex(2) as? [String: NSArray] {
                    for (letter, array) in serializedEdges {
                        edges?[Character(letter)] = DawgNode.deserialize(array, cached: &cached)
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
    
    func serialize() -> NSArray {
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
    
    func updateDescription() {
        var arr = [final ? "1" : "0"]
        arr.appendContentsOf(edges.map({ "\($0.0)_\($0.1)" }))
        descr = arr.joinWithSeparator("_")
    }
    
    func setEdge(letter: Character, node: DawgNode) {
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

class Dawg {
    var rootNode: DawgNode
    var previousWord = ""
    
    lazy var uncheckedNodes = [(parent: DawgNode, letter: Character, child: DawgNode)]()
    lazy var minimizedNodes = [DawgNode: DawgNode]()
    
    /// Initialize a new instance.
    init() {
        rootNode = DawgNode()
    }
    
    /// Initialize with an existing root node, carrying over all hierarchy information.
    /// - parameter rootNode: Node to use.
    init(withRootNode rootNode: DawgNode) {
        self.rootNode = rootNode
    }
    
    /// Attempt to save structure to file.
    /// - parameter path: Path to write to.
    func save(path: String) -> Bool {
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
    class func load(path: String) -> Dawg? {
        do {
            if let data = NSData(contentsOfFile: path),
                contents = try NSJSONSerialization.JSONObjectWithData(data,
                    options: NSJSONReadingOptions.AllowFragments) as? NSArray {
                        var cache = [Int: DawgNode]()
                        return Dawg(withRootNode: DawgNode.deserialize(contents, cached: &cache))
            }
        } catch { }
        return nil
    }
    
    /// Replace redundant nodes in uncheckedNodes with ones existing in minimizedNodes
    /// then truncate.
    /// - parameter downTo: Iterate from count to this number (truncates these items).
    func minimize(downTo: Int) {
        for i in (downTo..<uncheckedNodes.count).reverse() {
            let (_, letter, child) = uncheckedNodes[i]
            if let minNode = minimizedNodes[child] {
                uncheckedNodes[i].parent.setEdge(letter, node: minNode)
            } else {
                minimizedNodes[child] = child
            }
            uncheckedNodes.popLast()
        }
    }
    
    /// Insert a word into the graph, words must be inserted in order.
    /// - parameter word: Word to insert.
    func insert(word: String) {
        if word == "" { return }
        assert(previousWord == "" || previousWord < word, "Words must be inserted alphabetically")
        
        // Find common prefix for word and previous word.
        var commonPrefix = 0
        let chars = Array(word.characters)
        let previousChars = Array(previousWord.characters)
        for i in 0..<min(chars.count, previousChars.count) {
            if chars[i] != previousChars[i] { break }
            commonPrefix++
        }
        
        // Minimize nodes before continuing.
        minimize(commonPrefix)
        
        // Add the suffix, starting from the correct node mid-way through the graph.
        var node = uncheckedNodes.last?.child ?? rootNode
        for letter in chars[commonPrefix..<chars.count] {
            let nextNode = DawgNode()
            node.setEdge(letter, node: nextNode)
            uncheckedNodes.append((node, letter, nextNode))
            node = nextNode
        }
        
        node.final = true
        previousWord = word
    }
    
    /// - parameter word: Word to check.
    /// - returns: True if the word exists.
    func lookup(word: String) -> Bool {
        var node = rootNode
        for letter in word.characters {
            guard let edgeNode = node.edges[letter] else { return false }
            node = edgeNode
        }
        return node.final
    }
    
    
    func anagramsOf(letters: [Character],
        length: Int,
        prefix: [Character],
        fixedLetters: [(Int, Character)],
        fixedCount: Int,
        root: DawgNode,
        inout results: [String])
    {
        let source = root ?? rootNode
        let prefixLength = prefix.count
        if let c = fixedLetters.filter({$0.0 == prefixLength}).map({$0.1}).first,
            newSource = source.edges[c] {
                var newPrefix = prefix
                newPrefix.append(c)
                //let newPrefix = prefix + String(c)
                let reverseFiltered = fixedLetters.filter({$0.0 != prefixLength})
                anagramsOf(letters, length: length, prefix: newPrefix,
                    fixedLetters: reverseFiltered, fixedCount: fixedCount,
                    root: newSource, results: &results)
                return
        }
        
        // See if word exists
        if source.final && fixedLetters.count == 0 &&
            prefixLength == length &&
            prefixLength > fixedCount {
                results.append(String(prefix))
        }
        
        source.edges.forEach { (letter, node) in
            // Search for ? or letter
            if let index = letters.indexOf(letter) ?? letters.indexOf("?") {
                var newPrefix = prefix
                var newLetters = letters
                newPrefix.append(letter)
                newLetters.removeAtIndex(index)
                anagramsOf(newLetters, length: length, prefix: newPrefix,
                    fixedLetters: fixedLetters, fixedCount: fixedCount,
                    root: node, results: &results)
            }
        }
    }
}