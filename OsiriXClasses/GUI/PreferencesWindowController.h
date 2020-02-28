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
#import <PreferencePanes/NSPreferencePane.h>
#import "SFAuthorizationView+OsiriX.h"

@class PreferencesView;

#pragma mark -

@interface PreferencesWindowContext : NSObject

@property(retain) NSString* title;
@property(retain) NSBundle* parentBundle;
@property(retain) NSString* resourceName;
@property(nonatomic, retain) NSPreferencePane* pane;

-(id)initWithTitle:(NSString*)title
 withResourceNamed:(NSString*)resourceName
          inBundle:(NSBundle*)parentBundle;

@end

#pragma mark -

/** \brief Window Controller for Preferences */
@interface PreferencesWindowController : NSWindowController <NSWindowDelegate>
{
	IBOutlet NSScrollView* scrollView;
	IBOutlet PreferencesView* panesListView;
	IBOutlet NSButton* authButton;
	IBOutlet SFAuthorizationView* authView;
	PreferencesWindowContext* currentContext;
	NSMutableArray* animations;
	IBOutlet NSView* flippedDocumentView;
}

@property(readonly) NSMutableArray* animations;
@property(readonly) SFAuthorizationView* authView;

+ (PreferencesWindowController*) sharedPreferencesWindowController;
+(void) addPluginPaneWithResourceNamed:(NSString*)resourceName
                              inBundle:(NSBundle*)parentBundle
                             withTitle:(NSString*)title
                                 image:(NSImage*)image;
+(void) removePluginPaneWithBundle:(NSBundle*)parentBundle;

-(BOOL)isUnlocked;

-(IBAction)showAllAction:(id)sender;
-(IBAction)navigationAction:(id)sender;
-(IBAction)authAction:(id)sender;

-(void)reopenDatabase;
-(void)setCurrentContextWithResourceName: (NSString*) name;
-(void)setCurrentContext:(PreferencesWindowContext*)context;
@end
