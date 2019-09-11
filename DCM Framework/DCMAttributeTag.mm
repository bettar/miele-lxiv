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

#import <DCM/DCMAttributeTag.h>
#import "DCM.h"

@implementation DCMAttributeTag

@synthesize group = _group, element = _element, name = _name, vr = _vr;

+ (id) tagWithGroup:(int)group element:(int)element{
	return [[[DCMAttributeTag alloc] initWithGroup:group element:element] autorelease];
}

+ (id) tagWithTag:(DCMAttributeTag *)tag{
	return [[[DCMAttributeTag alloc] initWithTag:(DCMAttributeTag *)tag] autorelease];
}

+ (id) tagWithTagString:(NSString *)tagString{
	return [[[DCMAttributeTag alloc] initWithTagString:tagString] autorelease];
}

+ (id) tagWithName:(NSString *)name{
	return [[[DCMAttributeTag alloc] initWithName:name] autorelease];
}

- (instancetype) initWithGroup:(int)group element:(int)element
{
    self = [super init];
	if (self) {
		_group = group;
		_element = element;
		_name = [@"Unknown" retain];
		_vr = nil;
		NSDictionary *dict = [(NSDictionary *)[DCMTagDictionary sharedTagDictionary] objectForKey:[self stringValue]];
		if (dict) {
            [_name release];
			_name = [[dict objectForKey:@"Description"] retain];
			_vr = [[dict objectForKey:@"VR"] retain];
		}
		
		if (!_vr)
			_vr = [@"UN" retain];
		/*
		if (![DCMValueRepresentation isValidVR:_vr])
			_vr = [@"UN" retain];
		*/
	}

    return self;
}

- (id) initWithTag:(DCMAttributeTag *)tag{
	return [self initWithGroup: tag.group element: tag.element];
}

- (instancetype) initWithTagString:(NSString *)tagString
{
    self = [super init];
	if (self)
	{
		NSScanner *scanner = [NSScanner scannerWithString:tagString];
		if( tagString == nil)
			NSLog( @"tagString == nil");

        unsigned int uGroup, uElement;
		[scanner scanHexInt:&uGroup];
		[scanner scanString:@"," intoString:nil];
		[scanner scanHexInt:&uElement];
		_group = (int)uGroup;
		_element = (int)uElement;

		NSDictionary *dict = [[DCMTagDictionary sharedTagDictionary] objectForKey:tagString];
		
		if (dict)
		{
			_name = [(NSString *)CFDictionaryGetValue((CFDictionaryRef)dict, @"Description") retain];
			_vr =	[(NSString *)CFDictionaryGetValue((CFDictionaryRef)dict, @"VR") retain];
		}
		if (!_vr)
			_vr = [@"UN" retain];
		/*
		if (![DCMValueRepresentation isValidVR:_vr])
			_vr = [@"UN" retain];
		*/
	}

    return self;
}

- (id) initWithName:(NSString *)name
{
	NSString *tagString = [(NSDictionary *)[DCMTagForNameDictionary sharedTagForNameDictionary] objectForKey:name];
	if (!tagString)
		return nil;

    return [self initWithTagString:tagString];
}

- (id)copyWithZone:(NSZone *)zone{
	return [[DCMAttributeTag allocWithZone:zone] initWithTag:self];
}

- (void) dealloc
{
	[_name release];
	[_vr release];
	[_stringValue release];
	[super dealloc];
}

- (BOOL)isPrivate
{
	if ((_group%2) == 0)
		return NO;

    return YES;
}

- (NSString *)stringValue
{
	if (!_stringValue)
		_stringValue = [[NSString alloc] initWithFormat:@"%0004X,%0004X", _group, _element];

    return _stringValue;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@\t%@\t%@", self.stringValue, _name, _vr];
}

- (NSString *)readableDescription
{
    if (_name.length > 0)
        return _name;

    return self.stringValue;
}

- (long)longValue
{
	NSLog(@"long Value for %@:%ld", self.description, (long)(_group<<16) + (long)(_element&0xffff));
	return (long)(_group<<16) + (long)(_element&0xffff);
}

- (NSComparisonResult)compare:(DCMAttributeTag *)tag
{
	//NSNumber *thisTag = [NSNumber numberWithLong:[self longValue]];
	//NSNumber *otherTag = [NSNumber numberWithLong:[tag longValue]];
	return [[self stringValue] compare: tag.stringValue];
}

- (BOOL)isEquaToTag:(DCMAttributeTag *)tag {
	return [[tag stringValue] isEqualToString: self.stringValue];
}

-(BOOL)isEqual:(id)object {
	return [object isKindOfClass:[DCMAttributeTag class]] && [self isEquaToTag:object];
}

@end
