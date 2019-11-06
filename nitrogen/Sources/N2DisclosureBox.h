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

@class N2DisclosureButtonCell;

extern NSString* N2DisclosureBoxDidToggleNotification;
extern NSString* N2DisclosureBoxWillExpandNotification;
extern NSString* N2DisclosureBoxDidExpandNotification;
extern NSString* N2DisclosureBoxWillCollapseNotification;
extern NSString* N2DisclosureBoxDidCollapseNotification;

@interface N2DisclosureBox : NSBox {
	BOOL _showingExpanded;
	IBOutlet NSView* _content;
	CGFloat _contentHeight;
}

@property BOOL enabled;
//@property(readonly) N2DisclosureButtonCell* titleCell;

-(id)initWithTitle:(NSString*)title content:(NSView*)view;
-(void)toggle:(id)sender;
-(void)expand:(id)sender;
-(void)collapse:(id)sender;
-(BOOL)isExpanded;
-(NSArray*)additionalSubviews;

@end
