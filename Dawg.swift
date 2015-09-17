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

struct DawgNode: CustomStringConvertible, Hashable {
    static var nextId = 0;
    
    typealias Edges = [Character: DawgNode]
    
    var edges: Edges
    var final: Bool = false
    var id: Int
    var descr: String = ""
    
    init() {
        self.id = self.dynamicType.nextId
        self.edges = Edges()
        self.dynamicType.nextId += 1
        updateDescription()
    }
    
    mutating func updateDescription() {
        var arr = [final ? "1" : "0"]
        edges.forEach({ (letter, node) in
            arr.append("\(letter)")
            arr.append("\(node.id)")
        })
        descr = arr.joinWithSeparator("_")
    }
    
    mutating func setEdge(letter: Character, node: DawgNode) {
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
}