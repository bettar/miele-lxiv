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

#import "ButtonAndTextCell.h"

@implementation ButtonAndTextCell

// NS_UNAVAILABLE: Use the designated initializer initTextCell:
//- (instancetype)initImageCell:(NSImage *)anImage
//{
//    self = [super initImageCell:anImage];
//    if (self)
//        NSLog(@"initImageCell");
//
//    return self;
//}

- (instancetype)initTextCell:(NSString *)aString
{
    self = [super initTextCell:aString];
	if (self)
		NSLog(@"initTextCell");

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
	if (self) {

		buttonCell = [[NSButtonCell alloc] initImageCell:nil];
		[buttonCell setButtonType:NSSwitchButton];
		[buttonCell  setControlSize:NSControlSizeMini];
		[buttonCell setState:NSOnState];
		
		//textCell = [[NSTextFieldCell alloc] initTextCell:@""];
		[self setBezeled:YES];
		[self setBezelStyle:NSTextFieldSquareBezel];
		[self setDrawsBackground:YES];
		[self setControlSize:NSControlSizeMini];
		[self setEditable:YES];
	}

	return self;
}

-(void)dealloc{
	[textCell release];
	[super dealloc];
}


- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView{
//	NSRect buttonFrame = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width/2- 10 , cellFrame.size.height);
//	NSRect textFrame = NSMakeRect(cellFrame.size.width/2 + 10, cellFrame.origin.y, cellFrame.size.width/2 - 10, cellFrame.size.height);
//	NSLog(@"draw Interior x:%f y:%f, width %f height %f", cellFrame.origin.x,cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
	//NSLog(@"drawInteriorWithFrame:");
	[super drawInteriorWithFrame:cellFrame inView:controlView];
//	[textCell drawInteriorWithFrame:textFrame inView:controlView];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect textFrame = NSMakeRect(NSMaxX(cellFrame) - 120,
                                  NSMinY(cellFrame),
                                  120,
                                  NSHeight(cellFrame));
	NSLog(@"drawWithFrame:");
	//[super drawWithFrame:buttonFrame inView:controlView];
	[textCell drawWithFrame:textFrame inView:controlView];
}

- (IBAction) peformAction:(id)sender{
/*
	if ([self state] == NSOnState)
		[textCell setEnabled:YES];
	else
		[textCell setEnabled:NO];

	NSLog(@"State:%d", [self state]);
*/
}
/*
- (void)setState:(int)value{
	[super setState:value];
	if ([self state] == NSOnState)
		[textCell setEnabled:YES];
	else
		[textCell setEnabled:NO];
}

- (BOOL)refusesFirstResponder{
	return NO;
}

- (BOOL)acceptsFirstResponder{
	return [textCell acceptsFirstResponder];
}
*/	
@end
