//
//  Dawg.swift
//  Dawg
//
//  Created by Chris Nevin on 16/09/2015.
//  Copyright © 2015 CJNevin. All rights reserved.
//

import Foundation

import Foundation

class DataBuffer {
    let data: NSData
    var offset: Int = 0
    init(_ data: NSData) {
        self.data = data
    }
    func getUInt8() -> UInt8 {
        var value: UInt8 = 0
        data.getBytes(&value, range: NSMakeRange(offset, 1))
        offset += 1
        return value
    }
    func getUInt32() -> UInt32 {
        var value: UInt32 = 0
        data.getBytes(&value, range: NSMakeRange(offset, 4))
        offset += 4
        return value
    }
}

typealias DawgLetter = UInt8

func == (lhs: DawgNode, rhs: DawgNode) -> Bool {
    return lhs.description == rhs.description
}

class DawgNode: CustomStringConvertible, Hashable {
    typealias Edges = [DawgLetter: DawgNode]
    
    static var nextId: UInt32 = 0
    lazy var edges = Edges()
    var descr: String = ""
    var final: Bool = false
    var id: UInt32
    
    init() {
        self.id = self.dynamicType.nextId
        self.dynamicType.nextId += 1
        updateDescription()
    }
    
    init(withId id: UInt32, final: Bool) {
        self.dynamicType.nextId = max(self.dynamicType.nextId, id)
        self.id = id
        self.final = final
    }
    
    class func deserialize(data: DataBuffer, inout cached: [UInt32: DawgNode]) -> DawgNode {
        let final = data.getUInt8() == 1
        let id = data.getUInt32()
        let count = data.getUInt32()
        var node: DawgNode
        if let cache = cached[id] {
            node = cache
        } else {
            node = DawgNode(withId: id, final: final)
            cached[id] = node
        }
        for _ in 0..<count {
            node.edges[data.getUInt8()] = deserialize(data, cached: &cached)
        }
        return node
    }
    
    func serialize() -> NSData {
        let data = NSMutableData()
        var finalByte: UInt8 = final ? 1 : 0
        data.appendBytes(&finalByte, length: 1)
        data.appendBytes(&id, length: 4)
        var count = edges.count
        data.appendBytes(&count, length: 4)
        for (var letter, node) in edges {
            data.appendBytes(&letter, length: 1)
            data.appendData(node.serialize())
        }
        return data
    }
    
    func updateDescription() {
        var arr = [final ? "1" : "0"]
        arr.appendContentsOf(edges.map({ "\($0.0)_\($0.1.id)" }))
        descr = arr.joinWithSeparator("_")
    }
    
    func setEdge(letter: DawgLetter, node: DawgNode) {
        edges[letter] = node
        updateDescription()
    }
    
    var description: String {
        return descr
    }
    
    var hashValue: Int {
        return self.description.hashValue
    }
}

public class Dawg {
    private var finalized: Bool = false
    private let rootNode: DawgNode
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
                    i++
                    if i >= characters.count { break }
                    char = characters[i]
                }
                dawg.insert(buffer)
                buffer.removeAll()
                i++
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
        let serialized = rootNode.serialize()
        serialized.writeToFile(path, atomically: true)
        return true
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
}