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

#import <AppKit/AppKit.h>

@interface OpacityTransferView : NSView
{
	IBOutlet NSTextField *position;
	NSMutableArray *points;
	NSUInteger curIndex;
	unsigned char red[256], green[256], blue[256];
}

- (NSMutableArray*) getPoints;
- (void) setCurrentCLUT :( unsigned char*) r : (unsigned char*) g : (unsigned char*) b;
- (IBAction) renderButton:(id) sender;
+ (NSData*) tableWith256Entries: (NSArray*) pointsArray;
+ (NSData*) tableWith4096Entries: (NSArray*) pointsArray;
@end
