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

#import "DICOMToNSString.h"
#import <DCM/DCMCharacterSet.h>

@implementation NSString (DICOMToNSString)

- (id) initWithCString:(const char *)cString  DICOMEncoding:(NSString *)encoding
{
	NSStringEncoding stringEncoding = [NSString encodingForDICOMCharacterSet: encoding];
	
	return [self initWithCString:cString  encoding:stringEncoding];
}

+ (id) stringWithCString:(const char *)cString  DICOMEncoding:(NSString *)encoding
{
	return [[[NSString alloc] initWithCString: cString  DICOMEncoding: encoding] autorelease];
}

//+ (NSArray *)allAvailableEncodings
//{
//	static NSArray *cachedArray = nil;
//	NSMutableArray *array;
//	const NSStringEncoding *encoding;
//	
//	if (cachedArray != nil)
//		return cachedArray;
//	
//	array = [[NSMutableArray alloc] initWithCapacity:0x40];
//	encoding = [NSString availableStringEncodings];
//    
//    while (*encoding) {
//		NSMutableArray* row = [[NSMutableArray alloc] initWithCapacity:2];
//		
//        [row addObject:[NSString localizedNameOfStringEncoding:*encoding]];
//        [row addObject:[NSNumber numberWithInt:*encoding]];
//        encoding++;
//        
//        [array addObject:row];
//        [row release];
//    }
//    
//	cachedArray = [array copy];
//	[array retain];
//    return cachedArray;
//}

// TODO: See same function in DCMCharacterSet
+ (NSStringEncoding)encodingForDICOMCharacterSet:(NSString *)characterSet
{
    return [DCMCharacterSet encodingForDICOMCharacterSet:characterSet];
}

@end
