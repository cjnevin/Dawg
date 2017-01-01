//
//  DawgTests.swift
//  Dawg
//
//  Created by Chris Nevin on 25/06/2016.
//  Copyright © 2016 CJNevin. All rights reserved.
//

import XCTest
@testable import Dawg

extension Dawg {
    static let singleton = Dawg.load(Bundle(for: DawgTests.self).path(forResource: "sowpods", ofType: "bin")!)!
}

class DawgTests: XCTestCase {
    
    let dawg = Dawg.singleton
    let blank = Character("?")
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func chars(_ str: String) -> [Character] {
        return Array(str.characters)
    }
    
    func testSerialize() {
        let serialized = dawg.serialize()
        let deserializedDawg = Dawg.deserialize(DataBuffer(serialized))
        XCTAssertNotNil(deserializedDawg)
        XCTAssertTrue(deserializedDawg!.lookup("cat"))
    }
    
    func testLookupSucceedsForLowercaseWord() {
        XCTAssertTrue(dawg.lookup("cart"))
    }
    
    func testLookupSucceedsForUppercaseWord() {
        XCTAssertTrue(dawg.lookup("SHE"))
    }
    
    func testLookupSucceedsForRandomcasedWord() {
        XCTAssertTrue(dawg.lookup("sHieLd"))
    }
    
    func testLookupFailsForInvalidWord() {
        XCTAssertFalse(dawg.lookup("xzysx"))
    }
    
    func testLoadFailsForInvalidFile() {
        XCTAssertNil(Dawg.load(""))
    }
    
    func testAnagramLookupSucceeds() {
        XCTAssertEqual(dawg.anagrams(withLetters: chars("cat"), wordLength: 3, blankLetter: blank)!.sorted(), ["act", "cat"])
    }
    
    func testAnagramLookupWithFilledLettersSucceeds() {
        var fixedLetters = [Int: Character]()
        fixedLetters[2] = "r"
        XCTAssertEqual(dawg.anagrams(withLetters: chars("tac"), wordLength: 4, filledLetters: fixedLetters, blankLetter: blank)!, ["cart"])
    }
    
    func testAnagramLookupWithWildcardsSucceeds() {
        XCTAssert(dawg.anagrams(withLetters: chars("sc\(blank)resheets"), wordLength: 11, blankLetter: blank)!.contains("scoresheets"))
    }
    
    func testLookupWithWordLengthAndFilledLettersReturnsResults() {
        var fixedLetters = [Int: Character]()
        fixedLetters[0] = "c"
        fixedLetters[2] = "r"
        XCTAssertEqual(dawg.anagrams(withLetters: chars("aeiou"), wordLength: 3, filledLetters: fixedLetters, blankLetter: blank)!.sorted(), ["car", "cor", "cur"])
    }
    
    func testLookupWithWordLengthReturnsResults() {
        XCTAssertEqual(dawg.anagrams(withLetters: chars("hair"), wordLength: 3, blankLetter: blank)!.sorted(), ["ahi", "air", "rah", "rai", "ria"])
    }
}
