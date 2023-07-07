//
//  miele_lxivTests.m
//  miele-lxivTests
//
//  Created by Alex Bettarini 03 Apr 2019
//  Copyright © 2019 bettar. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Point3D.h"

@interface miele_lxivTests : XCTestCase

@end

#pragma mark -

@implementation miele_lxivTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample
{
    int a = 3;
    BOOL trueValue = YES;
    
    XCTAssertEqual(a, 3, @"a3");
    XCTAssertTrue(trueValue, @"trueValue should be true at this point");
    
    Point3D *a3DPoint;
    
    a3DPoint=[Point3D alloc];
    XCTAssertNotNil(a3DPoint);
    
    [a3DPoint initWithValues: 10.2 : 10.3 : 10.4];
    XCTAssertEqual((float) 10.2, [a3DPoint x], @"3D x");
    XCTAssertEqual((float) 10.3, [a3DPoint y], @"3D y");
    XCTAssertEqual((float) 10.4, [a3DPoint z], @"3D z");
    
    [a3DPoint multiply: 201.5];
    XCTAssertEqual((float) 2055.3, [a3DPoint x], @"3D x");
    XCTAssertEqual((float) 2075.45, [a3DPoint y], @"3D y");
    XCTAssertEqualWithAccuracy((float) 2095.6, [a3DPoint z], 0.01, @"3D z");
    
    if (![[a3DPoint description] isEqualToString: @"Point3D ( 2055.300049, 2075.449951, 2095.599854 )"])
        XCTFail(@"%@", [a3DPoint description]);
    
    [a3DPoint release];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
