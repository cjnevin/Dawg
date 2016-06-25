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
        let input = NSBundle(forClass: self.dynamicType).pathForResource("test", ofType: "txt")!
        let output = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true).first! + "/output.txt"
        XCTAssertTrue(DawgBuilder.create(input, outputPath: output))
        
        let data = try! NSString(contentsOfFile: input, encoding: NSUTF8StringEncoding)
        let lines = data.componentsSeparatedByString("\n").sort()
        XCTAssert(lines.count > 0)
        let reader = Dawg.load(output)!
        for line in lines {
            XCTAssertTrue(reader.lookup(line), "\(line) invalid")
        }
    }
}