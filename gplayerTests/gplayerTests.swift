//
//  gplayerTests.swift
//  gplayerTests
//
//  Created by DoubleLight on 2020/10/29.
//  Copyright © 2020 dminoror. All rights reserved.
//

import XCTest
@testable import gplayer

class gplayerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        var page: PlayerPage? = PlayerPage()
        let exp = expectation(description: "page has deinited")
        page?.deinitCalled = {
            exp.fulfill()
        }
        DispatchQueue.global(qos: .background).async {
            page = nil
        }
        waitForExpectations(timeout: 2)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
