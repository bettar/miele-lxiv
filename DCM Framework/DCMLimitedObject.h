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

#import <Cocoa/Cocoa.h>
#import <DCM/DCMObject.h>

@interface DCMLimitedObject : DCMObject {

}

+ (id)objectWithData:(NSData *)data lastGroup:(unsigned short)lastGroup;
+ (id)objectWithContentsOfFile:(NSString *)file lastGroup:(unsigned short)lastGroup;
+ (id)objectWithContentsOfURL:(NSURL *)aURL lastGroup:(unsigned short)lastGroup;

- (id)initWithData:(NSData *)data lastGroup:(unsigned short)lastGroup;
- (id)initWithContentsOfFile:(NSString *)file lastGroup:(unsigned short)lastGroup;
- (id)initWithContentsOfURL:(NSURL *)aURL lastGroup:(unsigned short)lastGroup;

- (id)initWithDataContainer:(DCMDataContainer *)data
               lengthToRead:(int)lengthToRead
                 byteOffset:(int*)byteOffset
               characterSet:(DCMCharacterSet *)characterSet
                  lastGroup:(unsigned short)lastGroup;

- (int)readDataSet:(DCMDataContainer *)dicomData
           toGroup:(unsigned short)lastGroup
        byteOffset:(int *)byteOffset;

@end
