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

#import <Foundation/Foundation.h>

@interface DCMCharacterSet : NSObject {
	NSStringEncoding encoding;
	NSStringEncoding *encodings;
	NSString *_characterSet;
}

@property(readonly) NSStringEncoding* encodings;
@property(readonly) NSStringEncoding encoding;
@property(readonly) NSString *characterSet, *description;

- (id)initWithCode:(NSString *)characterSet;
- (id)initWithCharacterSet:(DCMCharacterSet *)characterSet;

+ (NSString *) stringWithBytes: (char *) str
                        length: (const size_t) length
                     encodings: (NSStringEncoding*) encodings;

+ (NSStringEncoding)encodingForDICOMCharacterSet:(NSString *)characterSet;

@end
