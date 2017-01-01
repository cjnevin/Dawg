//
//  DawgBuilderTests.swift
//  Dawg
//
//  Created by Chris Nevin on 25/06/2016.
//  Copyright © 2016 CJNevin. All rights reserved.
//

import XCTest
@testable import Dawg

class DawgBuilderTests: XCTestCase {
    func testBuilder() {
        let input = Bundle(for: type(of: self)).path(forResource: "test", ofType: "txt")!
        let output = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! + "/output.txt"
        XCTAssertTrue(DawgBuilder.build(readingFrom: input, writingTo: output))
        
        let data = try! NSString(contentsOfFile: input, encoding: String.Encoding.utf8.rawValue)
        let lines = data.components(separatedBy: "\n").sorted().filter({ $0.lengthOfBytes(using: .utf8) > 0 })
        XCTAssert(lines.count > 0)
        let reader = Dawg.load(from: output)!
        for line in lines {
            XCTAssertTrue(reader.lookup(line), "\(line) invalid")
        }
    }
}
