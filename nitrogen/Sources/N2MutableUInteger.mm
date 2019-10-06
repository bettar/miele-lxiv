//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:
/*=========================================================================
 Program:   OsiriX
 
 Copyright (c) OsiriX Team
 All rights reserved.
 Distributed under GNU - LGPL
 
 See http://www.osirix-viewer.com/copyright.html for details.
 
 This software is distributed WITHOUT ANY WARRANTY; without even
 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.
 =========================================================================*/

#import "N2MutableUInteger.h"

@implementation N2MutableUInteger

@synthesize unsignedIntegerValue = _value;

+(id)mutableUIntegerWithUInteger:(NSUInteger)value {
	return [[[[self class] alloc] initWithUInteger:value] autorelease];
}

-(id)initWithUInteger:(NSUInteger)value
{
    self = [super init];
	if (self) {
		_value = value;
	}
	
	return self;
}

-(void)increment {
	++_value;
}

-(void)decrement {
	if (_value)
        --_value;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<N2MutableUInteger: %llu>", (long long)_value];
}

@end
