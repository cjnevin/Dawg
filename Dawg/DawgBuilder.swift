//
//  DawgBuilder.swift
//  Dawg
//
//  Created by Chris Nevin on 25/06/2016.
//  Copyright © 2016 CJNevin. All rights reserved.
//

import Foundation

func == (lhs: DawgBuilderNode, rhs: DawgBuilderNode) -> Bool {
    return lhs.descr == rhs.descr
}

class DawgBuilderNode: CustomStringConvertible, Hashable, CustomDebugStringConvertible {
    typealias Edges = [DawgLetter: DawgBuilderNode]

    fileprivate static var nextId: UInt32 = 0
    fileprivate var descr: String = ""
    lazy var edges = Edges()
    var final: Bool = false
    var id: UInt32
    
    /// Create a new node while building a new Dawg.
    init() {
        self.id = type(of: self).nextId
        type(of: self).nextId += 1
        updateDescription()
    }
    
    /// Create a new node with existing data into an existing Dawg.
    /// - parameter id: Node identifier.
    /// - parameter final: Whether this node terminates a word.
    init(withId id: UInt32, final: Bool) {
        type(of: self).nextId = max(type(of: self).nextId, id)
        self.id = id
        self.final = final
    }
    
    func updateDescription() {
        var arr = [final ? "1" : "0"]
        arr.append(contentsOf: edges.map({ "\($0.0)_\($0.1.id)" }))
        descr = arr.joined(separator: "_")
    }
    
    func setEdge(_ letter: DawgLetter, node: DawgBuilderNode) {
        edges[letter] = node
        updateDescription()
    }
    
    var description: String {
        return descr
    }
    
    var debugDescription: String {
        return "id: \(id), final: \(final)"
    }
    
    var hashValue: Int {
        return descr.hashValue
    }
}

open class DawgBuilder {
    fileprivate var finalized: Bool = false
    internal let rootNode: DawgBuilderNode
    fileprivate var previousChars: [Character] = []
    fileprivate lazy var uncheckedNodes = [(parent: DawgBuilderNode, letter: DawgLetter, child: DawgBuilderNode)]()
    fileprivate lazy var minimizedNodes = [DawgBuilderNode: DawgBuilderNode]()
    
    /// Initialize a new instance.
    public init() {
        rootNode = DawgBuilderNode()
    }
    
    /// Initialize with an existing root node, carrying over all hierarchy information.
    /// - parameter rootNode: Node to use.
    fileprivate init(withRootNode rootNode: DawgBuilderNode) {
        self.rootNode = rootNode
        finalized = true
    }
    
    /// Attempt to create a Dawg structure from a file.
    /// - parameter inputPath: Path to load wordlist from.
    /// - parameter outputPath: Path to write binary Dawg file to.
    open class func create(from inputPath: String, to outputPath: String) -> Bool {
        do {
            let data = try String(contentsOfFile: inputPath, encoding: String.Encoding.utf8)
            let dawg = DawgBuilder()
            let characters = Array(data.characters)
            let newLine = "\n".characters.first!
            var buffer = [Character]()
            var i = 0
            var newlineCounter = 0
            let newlines = characters.filter({$0 == newLine}).count
            repeat {
                var char = characters[i]
                while char != newLine
                {
                    buffer.append(char)
                    i += 1
                    if i >= characters.count { break }
                    char = characters[i]
                }
                if newlineCounter % 10000 == 0 {
                    print(newlineCounter, CGFloat(newlineCounter) / CGFloat(newlines) * 100, "%")
                }
                newlineCounter += 1
                if buffer.count > 0 {
                    dawg.insert(buffer)
                }
                buffer.removeAll()
                i += 1
            } while i < characters.count
            dawg.minimize(downTo: 0)
            dawg.save(outputPath)
            return true
        } catch {
            return false
        }
    }
    
    /// Attempt to save structure to file.
    /// - parameter path: Path to write to.
    @discardableResult fileprivate func save(_ path: String) -> Bool {
        return ((try? Dawg(root: rootNode).serialize().write(to: URL(fileURLWithPath: path), options: [.atomic])) != nil)
    }
    
    /// Replace redundant nodes in uncheckedNodes with ones existing in minimizedNodes
    /// then truncate.
    /// - parameter downTo: Iterate from count to this number (truncates these items).
    fileprivate func minimize(downTo: Int) {
        for i in (downTo..<uncheckedNodes.count).reversed() {
            let (parent, letter, child) = uncheckedNodes[i]
            if let node = minimizedNodes[child] {
                parent.setEdge(letter, node: node)
            } else {
                minimizedNodes[child] = child
            }
            uncheckedNodes.removeLast()
        }
    }
    
    /// Insert a word into the graph, words must be inserted in order.
    /// - parameter chars: UInt8 array.
    @discardableResult fileprivate func insert(_ chars: [Character]) -> Bool {
        if finalized { return false }
        var commonPrefix = 0
        for i in 0..<min(chars.count, previousChars.count) {
            if chars[i] != previousChars[i] { break }
            commonPrefix += 1
        }
        
        // Minimize nodes before continuing.
        minimize(downTo: commonPrefix)
        
        var node: DawgBuilderNode
        if uncheckedNodes.count == 0 {
            node = rootNode
        } else {
            node = uncheckedNodes.last!.child
        }
        
        // Add the suffix, starting from the correct node mid-way through the graph.
        //var node = uncheckedNodes.last?.child ?? rootNode
        chars[commonPrefix..<chars.count].forEach {
            let nextNode = DawgBuilderNode()
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
    @discardableResult open func insert(_ word: String) -> Bool {
        return insert(Array(word.characters))
    }
}
