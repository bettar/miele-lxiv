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

#import "NSView+N2.h"
#import "N2Operators.h"

@implementation NSView (N2)

- (void)setRecursiveEnabled:(BOOL)enabled
{
	if( [self respondsToSelector:@selector(setEnabled:)])
		[(NSControl *)self setEnabled:enabled];
		
	for( NSView *subview in [self subviews])
		[subview setRecursiveEnabled:enabled];
}

-(id)initWithSize:(NSSize)size {
	return [self initWithFrame:NSMakeRect(NSZeroPoint, size)];
}

-(NSRect)sizeAdjust {
	return NSZeroRect;
}

- (NSImage *) screenshotByCreatingPDF {
	NSData *imageData = [self dataWithPDFInsideRect: [self bounds]];
	return [[[NSImage alloc] initWithData: imageData] autorelease];
}
@end
