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

#import "PluginFilter.h"
#import <Cocoa/Cocoa.h>

#define PLUGIN_EXTENSION        @"mieleplugin"

// InfoPlist.strings (localizable)
#define PINFO_CF_BUNDLE_NAME    @"CFBundleName"

// Info.plist
#define PINFO_CF_BUNDLE_EXE     @"CFBundleExecutable"
#define PINFO_REQUIREMENTS      @"Requirements"
#define PINFO_TYPE              @"pluginType"
#define PINFO_MENU_TITLES       @"MenuTitles"
#define PINFO_TB_NAMES          @"ToolbarNames"
#define PINFO_TB_ICON_ALLOW     @"allowToolbarIcon"
#define PINFO_TB_ICON           @"ToolbarIcon"
#define PINFO_TB_TOOLTIPS       @"ToolbarToolTips"
#define PINFO_FILE_FORMATS      @"FileFormats"

// For PINFO_TYPE:
#define PTYPE_DATABASE          @"Database"
#define PTYPE_FUSION_FILTER     @"fusionFilter"
#define PTYPE_IMAGE_FILTER      @"imageFilter"
#define PTYPE_PRE_PROCESS       @"Pre-Process"
#define PTYPE_REPORT            @"Report"
#define PTYPE_ROI_TOOL          @"roiTool"
#define PTYPE_OTHER             @"other"

// For PINFO_MENU_TITLES
// Put this in a line by itself to have a separator in the menu entries
#define PINFO_MENU_ITEM_SEPARATOR   @"(-"

/** \brief Mangages PluginFilter loading */
@interface PluginManager : NSObject
{
	NSMutableArray *downloadQueue;
	BOOL startedUpdateProcess;
}

@property(retain,readwrite) NSMutableArray *downloadQueue;

+ (int) compareVersion: (NSString *) v1 withVersion: (NSString *) v2;
+ (NSMutableDictionary*) installedPlugins;
+ (NSMutableDictionary*) installedPluginsInfoDict;
+ (NSMutableDictionary*) fileFormatPlugins;
+ (NSMutableDictionary*) reportPlugins;
+ (NSArray*) preProcessPlugins;
+ (NSMenu*) fusionPluginsMenu;
+ (NSArray*) fusionPlugins;

+ (void) startProtectForCrashWithFilter: (id) filter;
+ (void) startProtectForCrashWithPath: (NSString*) path;
+ (void) endProtectForCrash;

#ifdef OSIRIX_VIEWER

+ (NSString*) pathResolved:(NSString*) inPath;
+ (void) discoverPlugins;
+ (void) unloadPluginWithName: (NSString*) name;
+ (void) loadPluginAtPath: (NSString*) path;
+ (void) setMenus:(NSMenu*) filtersMenu :(NSMenu*) roisMenu :(NSMenu*) othersMenu :(NSMenu*) dbMenu;
+ (BOOL) isComPACS;
+ (void) installPluginFromPath: (NSString*) path;
+ (NSString*)activePluginsDirectoryPath;
+ (NSString*)inactivePluginsDirectoryPath;
+ (NSString*)userActivePluginsDirectoryPath;
+ (NSString*)userInactivePluginsDirectoryPath;
+ (NSString*)systemActivePluginsDirectoryPath;
+ (NSString*)systemInactivePluginsDirectoryPath;
+ (NSString*)appActivePluginsDirectoryPath;
+ (NSString*)appInactivePluginsDirectoryPath;
+ (NSArray*)activeDirectories;
+ (NSArray*)inactiveDirectories;
+ (void)movePluginFromPath:(NSString*)sourcePath toPath:(NSString*)destinationPath;
+ (void)activatePluginWithName:(NSString*)pluginName;
+ (void)deactivatePluginWithName:(NSString*)pluginName;
+ (void)changeAvailabilityOfPluginWithName:(NSString*)pluginName to:(NSString*)availability;
+ (NSString*)deletePluginWithName:(NSString*)pluginName;
+ (NSString*) deletePluginWithName:(NSString*)pluginName availability: (NSString*) availability isActive:(BOOL) isActive;
+ (NSArray*)pluginsList;
+ (void)createDirectory:(NSString*)directoryPath;
+ (NSArray*)availabilities;

- (IBAction)checkForPluginUpdates:(id)sender;
- (void)displayUpdateMessage:(NSDictionary*)messageDictionary;

#endif

@end
