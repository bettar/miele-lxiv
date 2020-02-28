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
#import <WebKit/WebKit.h>
#import "PluginManager.h"

/** \brief Window Controller for PluginFilter management */

@interface PluginsTableView : NSTableView
{

}
@end

#pragma mark -

@interface PluginManagerController : NSWindowController <NSURLDownloadDelegate, WebPolicyDelegate>
{
    IBOutlet NSMenu	*filtersMenu;
	IBOutlet NSMenu	*roisMenu;
	IBOutlet NSMenu	*othersMenu;
	IBOutlet NSMenu	*dbMenu;

	NSMutableArray* plugins;
	IBOutlet NSArrayController* pluginsArrayController;
	IBOutlet PluginsTableView *pluginTable;
	
	IBOutlet NSTabView *tabView;
	IBOutlet NSTabViewItem *installedPluginsTabViewItem, *webViewTabViewItem;
	
	IBOutlet WebView *webView;
	NSArray *pluginsListURLs;
	IBOutlet NSPopUpButton *pluginsListPopUp;
    NSDictionary *downloadUrlDict;
	IBOutlet NSButton *downloadButton;
	IBOutlet NSTextField *statusTextField;
	IBOutlet NSProgressIndicator *statusProgressIndicator;
    
    NSMutableDictionary *downloadingPlugins;
}

- (NSMutableArray*)plugins;
- (NSArray*)availabilities;
- (IBAction)modifiyActivation:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)modifiyAvailability:(id)sender;
- (IBAction)loadPlugins:(id)sender;
- (void)refreshPluginList;

- (NSArray*)availableRemotePlugins;
- (void)generateAvailablePluginsMenu;
- (void)setURL:(NSString*)url;
- (IBAction)changeWebView:(id)sender;
- (void)setURLforPluginWithName:(NSString*)name;

- (void)setDownloadUrlDict:(NSDictionary*)urlDict;
- (IBAction)download:(id)sender;

- (void)installDownloadedPluginAtPath:(NSString*)path;
- (BOOL)isZippedFileAtPath:(NSString*)path;
- (BOOL)unZipFileAtPath:(NSString*)path;
- (void)loadSubmitPluginPage;

@end
