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

#import "PreferencesView.h"
#import "N2Debug.h"
#import "NSImage+N2.h"
#import "N2Operators.h"
#include <algorithm>  // for std::max
#import "PreferencesWindowController.h"

#pragma mark -

@interface PreferencesViewGroup : NSObject {
	NSTextField* label;
	NSMutableArray* buttons;
}

@property(readonly) NSTextField* label;
@property(readonly) NSMutableArray* buttons;

-(id)initWithName:(NSString*)name;

@end

#pragma mark -

@implementation PreferencesViewGroup

@synthesize label;
@synthesize buttons;

-(id)initWithName:(NSString*)name {
	self = [super init];
	
	buttons = [[NSMutableArray alloc] init];
	
	label = [[NSTextField alloc] initWithFrame:NSZeroRect];
	[label setStringValue:name];
	[label setEditable:NO];
	[label setDrawsBackground:NO];
	[label setBordered:NO];
	[label setSelectable:NO];
	[label setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
	
	return self;
}

-(void)dealloc {
	[label release];
	[buttons release];
	[super dealloc];
}

@end

#pragma mark -

@interface PreferencesViewButtonCell : NSButtonCell
@end

#pragma mark -

@implementation PreferencesViewButtonCell

static const NSInteger labelHeight = 38, labelSeparator = 3;

-(void)drawWithFrame:(NSRect)frame inView:(NSView*)controlView
{
	[NSGraphicsContext saveGraphicsState];
	
	NSAffineTransform* transform = [NSAffineTransform transform];
	[transform translateXBy:0 yBy:frame.size.height];
	[transform scaleXBy:1 yBy:-1];
	[transform concat];
	
	NSRect imageRect = NSMakeRect(frame.origin.x,
                                  frame.origin.y+labelHeight+labelSeparator,
                                  frame.size.width,
                                  frame.size.height-labelHeight-labelSeparator);
	
	NSImage* image = [self isHighlighted] ? self.alternateImage : self.image;
	NSSize imageSize = [image size];
	if (imageSize.width > 32 || imageSize.height > 32)
        [image setSize:imageSize = NSMakeSize(32,32)];
    
	[image drawAtPoint: imageRect.origin+NSMakePoint((imageRect.size.width-imageSize.width)/2, 0)
              fromRect: NSMakeRect(NSZeroPoint, imageSize) // N2Operators.mm
             operation: NSCompositeSourceOver fraction:1];

	[NSGraphicsContext restoreGraphicsState];
	
	NSRect labelRect = NSMakeRect(frame.origin.x,
                                  frame.size.height-labelHeight,
                                  frame.size.width,
                                  labelHeight);
	
	NSMutableParagraphStyle* style = [[[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setAlignment:NSCenterTextAlignment];
	NSFont* font = [NSFont labelFontOfSize:[NSFont smallSystemFontSize]];
	NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                style, NSParagraphStyleAttributeName,
                                font, NSFontAttributeName,
                                [NSColor textColor], NSForegroundColorAttributeName,
								NULL];
	[self.title drawInRect:labelRect withAttributes:attributes];
}

@end

#pragma mark -

@interface PreferencesView (Private)

-(void)layout;

@end

#pragma mark -

@implementation PreferencesView

@synthesize buttonActionTarget;
@synthesize buttonActionSelector;

-(id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	
	groups = [[NSMutableArray alloc] init];
	
	return self;
}

-(void)dealloc {
	[groups release];
	[super dealloc];
}

-(PreferencesViewGroup*)groupWithName:(NSString*)name
{
	PreferencesViewGroup* group = NULL;
	for (PreferencesViewGroup* g in groups)
        if ([g.label.stringValue isEqualToString:name]) {
			group = g;
            break;
        }

	if (!group) {
        // Create new group
		group = [[[PreferencesViewGroup alloc] initWithName:name] autorelease];
		[self addSubview:group.label];
		[groups addObject:group];
	}
	
	return group;
}

-(void)removeItemWithBundle: (NSBundle*) bundle
{
    for (PreferencesViewGroup* group in groups)
    {
        for( NSButton *button in group.buttons)
        {
            PreferencesWindowContext *context = [[button cell] representedObject];
            
            if( [context parentBundle] == bundle)
            {
                [group.buttons removeObject:button];
                [self layout];
                return;
            }
        }
    }
}

-(void)addItemWithTitle:(NSString*)title
                  image:(NSImage*)image
        toGroupWithName:(NSString*)groupName
                context:(id)context
{
	PreferencesViewGroup* group = [self groupWithName:groupName];
	
	NSButton* button = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
	[button setCell:[[[PreferencesViewButtonCell alloc] init] autorelease]];
	[button setTitle:title];
	[button setImage:image];
	[button setAlternateImage:[image shadowImage]];
	[button setTarget:self];
	[button setAction:@selector(buttonAction:)];
	[[button cell] setRepresentedObject:context];
	[self addSubview:button];
	
	[group.buttons addObject:button];
	
	[self layout]; // Redisplay everything for each new button added
}

-(BOOL)isOpaque {
	return NO;
}

-(void)buttonAction:(NSButton*)sender
{
    //NSLog(@"%s %d", __FUNCTION__, __LINE__);
	[[self buttonActionTarget] performSelector:[self buttonActionSelector]
                                    withObject:[[sender cell] representedObject]];
}

-(NSUInteger)itemsCount {
	NSUInteger count = 0;
	for (PreferencesViewGroup* group in groups)
		count += group.buttons.count;
    
	return count;
}

-(id)contextForItemAtIndex:(NSUInteger)index {
	NSUInteger count = 0;
	for (NSUInteger r = 0; r < groups.count; ++r) {
		NSArray* buttons = [[groups objectAtIndex:r] buttons];
		if (count+buttons.count > index)
			return [[[buttons objectAtIndex:index-count] cell] representedObject];
        
		count += buttons.count;
	}
	
	return NULL;
}

-(NSInteger)indexOfItemWithContext:(id)context {
	NSUInteger count = 0;
	for (NSUInteger r = 0; r < groups.count; ++r)
		for (NSButton* button in [[groups objectAtIndex:r] buttons])
			if ([[button cell] representedObject] == context)
				return count;
			else
                ++count;
    
	return -1;
}

static const NSUInteger colWidth = 80, colSeparator = 1, rowHeight = 101, titleHeight = 20;
static const NSPoint titleMargin = NSMakePoint(6,3);
static const NSUInteger padTop = 0;
static const NSUInteger padRight = 16;
static const NSUInteger padBottom = 1;
static const NSUInteger padLeft = 6;

-(void)drawRect:(NSRect)dirtyRect
{
    [NSGraphicsContext saveGraphicsState];
	
	NSRect frame = [self bounds];
	
//	[[self backgroundColor] setFill];
//	[NSBezierPath fillRect:frame];
	
    // Slightly different background for alternate groups (rows)
    [[NSColor textBackgroundColor] setFill];
	[[NSColor colorWithCalibratedWhite:207./255 alpha:1] setStroke];
	[NSBezierPath setDefaultLineWidth:1];
	for (NSUInteger r = 1; r < groups.count; r += 2) {
        NSRect rect = NSMakeRect(0, frame.size.height-rowHeight*r-rowHeight-padTop, frame.size.width, rowHeight);
		[NSBezierPath fillRect:rect];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y+.5)
                                  toPoint:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+.5)];
        
		[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height-.5)
                                  toPoint:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height-.5)];
	}
	
	[NSGraphicsContext restoreGraphicsState];
	
//	[super drawRect:];
}

@end

#pragma mark -

@implementation PreferencesView (Private)

-(void)layout
{
	NSUInteger colsCount = 0;
	for (PreferencesViewGroup* group in groups)
		colsCount = std::max(colsCount, group.buttons.count);
	
	NSRect frame = [self frame];
    frame = NSMakeRect(frame.origin.x,
                       frame.origin.y,
                       padLeft + (colWidth+colSeparator)*colsCount - colSeparator+padRight,
                       padBottom + rowHeight*groups.count + padTop);
	[self setFrame:frame];
   
    // Lay them out bottom-up because the origin is in the bottom-left corner of the view
	for (NSInteger r = (long)groups.count-1; r >= 0; --r) {
		PreferencesViewGroup* group = [groups objectAtIndex:r];
		NSRect rowRect = NSMakeRect(padLeft,
                                    frame.size.height - rowHeight*r - rowHeight-padTop,
                                    frame.size.width - padLeft - padRight,
                                    rowHeight);
		
        [group.label setFrame:NSMakeRect(rowRect.origin.x+titleMargin.x,
                                         rowRect.origin.y+rowRect.size.height-titleHeight-titleMargin.y,
                                         rowRect.size.width-titleMargin.x*2,
                                         titleHeight)];
		
		for (NSUInteger i = 0; i < group.buttons.count; ++i) {
			NSButton* button = [group.buttons objectAtIndex:i];
			NSRect rect = NSMakeRect(rowRect.origin.x+(colWidth+colSeparator)*i,
                                     rowRect.origin.y,
                                     colWidth,
                                     rowHeight);
			[button setFrame:rect];
		}
	}
    
    [super layout];
}

@end
