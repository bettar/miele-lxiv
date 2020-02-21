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

@interface ColorTransferView : NSView {

	IBOutlet		NSColorWell *pick;
	IBOutlet		NSTextField *position;
	
	NSMutableArray  *colors;
	NSMutableArray  *points;
	
	NSUInteger curIndex;
}

-(void) selectPicker:(id) sender;
-(NSMutableArray*) getPoints;
-(NSMutableArray*) getColors;
-(void) ConvertCLUT:(unsigned char*) red : (unsigned char*) green : (unsigned char*) blue;
-(IBAction) renderButton:(id) sender;
@end
