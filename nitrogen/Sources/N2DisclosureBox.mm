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

#import <N2DisclosureBox.h>
#import <N2DisclosureButtonCell.h>
#import <N2Operators.h>

NSString* N2DisclosureBoxDidToggleNotification = @"N2DisclosureBoxDidToggleNotification";
NSString* N2DisclosureBoxWillExpandNotification = @"N2DisclosureBoxWillExpandNotification";
NSString* N2DisclosureBoxDidExpandNotification = @"N2DisclosureBoxDidExpandNotification";
NSString* N2DisclosureBoxDidCollapseNotification = @"N2DisclosureBoxDidCollapseNotification";

@implementation N2DisclosureBox

-(id)initWithTitle:(NSString*)title content:(NSView*)content {
    self = [super initWithFrame:NSZeroRect];
	
	// NSBox
	[self setTitlePosition:NSAtTop];
	[self setBorderType:NSBezelBorder];
	[self setBoxType:NSBoxPrimary];
	[self setAutoresizesSubviews:YES];
	
//	if (self.titleCell) [self.titleCell release]; // [NSBox dealloc] will later release the object we will now create
//	self.titleCell = [[N2DisclosureButtonCell alloc] init];
	[self.titleCell setTitle:title];
	[self.titleCell setState:NSControlStateValueOff];
	[self.titleCell setTarget:self];
	[self.titleCell setAction:@selector(toggle:)];
	
	_content = [content retain];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contentViewFrameDidChange:) name:NSViewFrameDidChangeNotification object:content];
	[self setFrameFromContentFrame:NSZeroRect];
	
    return self;
}

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_content release];
	[super dealloc];
}

-(void)mouseDown:(NSEvent*)event {
	if (NSPointInRect([event locationInWindow], [self convertRect:[self titleRect] toView:NULL]))
		[self.titleCell trackMouse:event inRect:[self titleRect] ofView:self untilMouseUp:YES];
	else
        [super mouseDown:event];
}

-(BOOL)enabled {
	return [self.titleCell isEnabled];
}

-(void)setEnabled:(BOOL)flag {
	[self.titleCell setEnabled:flag];
}

-(BOOL)isExpanded {
	return [self.titleCell state] == NSControlStateValueOn;
}

-(void)toggle:(id)sender {
	if ([self isExpanded])
		[self expand:sender];
	else
        [self collapse:sender];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:N2DisclosureBoxDidToggleNotification object:self];
}

-(void)expand:(id)sender {
	if (_showingExpanded)
        return;
    
	[[NSNotificationCenter defaultCenter] postNotificationName:N2DisclosureBoxWillExpandNotification object:self];
	_showingExpanded = YES;
	
	[self setFrameFromContentFrame:[_content frame]];
	[self addSubview:_content];
	
	[self.titleCell setState:NSControlStateValueOn];
	[[NSNotificationCenter defaultCenter] postNotificationName:N2DisclosureBoxDidExpandNotification object:self];
}

-(void)collapse:(id)sender {
	if (!_showingExpanded)
        return;
    
	_showingExpanded = NO;
	
	[_content removeFromSuperview];
	[self setFrameFromContentFrame:NSZeroRect];
	
	[self.titleCell setState:NSControlStateValueOff];
	[[NSNotificationCenter defaultCenter] postNotificationName:N2DisclosureBoxDidCollapseNotification object:self];
}

-(void)contentViewFrameDidChange:(NSNotification*)notification {
	[self setFrameFromContentFrame:[_content frame]];
}

-(void)setFrameFromContentFrame:(NSRect)contentFrame {
	NSSize margins = [self contentViewMargins];
	NSRect frame = contentFrame + NSMakeSize(margins.width*2, [self.titleCell textSize].height+margins.height*2);
	if (frame.size != [self frame].size) [self setFrameSize:frame.size];
}

-(void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize {
	[super resizeSubviewsWithOldSize:oldBoundsSize];
//	if ([self isExpanded]) [_content setFrameSize:[]];
	[self.titleCell calcDrawInfo:[self frame]];
}

-(void)setTitle:(NSString*)title {
	[self.titleCell setTitle:title];
	[self.titleCell setAlternateTitle:title];
}

-(NSString*)title {
	return [self.titleCell title];
}

-(NSSize)optimalSizeForWidth:(CGFloat)width {
	NSSize size = [self frame].size;
	size.width = width;
	return n2::ceil(size);
}

-(NSArray*)additionalSubviews {
	return [NSArray arrayWithObject:_content];
}

@end
