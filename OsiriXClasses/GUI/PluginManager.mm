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

#import "PluginManager.h"
#import "ViewerController.h"
#import "AppController.h"
#import "BrowserController.h"
#import "BLAuthentication.h"
#import "PluginManagerController.h"
#import "Notifications.h"
#import "NSFileManager+N2.h"
#import "NSMutableDictionary+N2.h"
#import "PreferencesWindowController.h"
#import "N2Debug.h"

#import "url.h"
#import "tmp_locations.h"

static NSMutableDictionary *installedPlugins = nil; // the actual plugin objects
static NSMutableDictionary *installedPluginsInfoDict = nil; // info about plugins: menu titles, toolbar name
static NSMutableDictionary *fileFormatPlugins = nil;
static NSMutableDictionary *reportPlugins = nil;
static NSMutableDictionary *pluginsBundleDictionary = nil;

static NSMutableArray			*preProcessPlugins = nil;
static NSMenu					*fusionPluginsMenu = nil;
static NSMutableArray			*fusionPlugins = nil;
static NSMutableDictionary		*pluginsNames = nil;
static BOOL						ComPACSTested = NO, isComPACS = NO;

BOOL gPluginsAlertAlreadyDisplayed = NO;

// 'PluginManager' lacks a 'dealloc' instance method but must release 'downloadQueue'
@implementation PluginManager

@synthesize downloadQueue;

+ (void) startProtectForCrashWithFilter: (id) filter
{
//    *(long*)0 = 0xDEADBEEF;
    
    for (NSBundle *bundle in [pluginsBundleDictionary allValues])
    {
        if ([NSStringFromClass( [filter class]) isEqualToString: NSStringFromClass( [bundle principalClass])])
        {
            [PluginManager startProtectForCrashWithPath: [bundle bundlePath]];
           
//            *(long*)0 = 0xDEADBEEF;
            
            return;
        }
    }
    
    NSLog( @"***** unknown plugin - startProtectForCrashWithFilter - %@", NSStringFromClass( [filter principalClass]));
}

+ (void) startProtectForCrashWithPath: (NSString*) path
{
    // Match with AppController, ILCrashReporter

    [path writeToFile: [NSTemporaryDirectory() stringByAppendingPathComponent:@"PluginCrashed"]
           atomically: YES
             encoding: NSUTF8StringEncoding
                error: nil];
}

+ (void) endProtectForCrash
{
    // Match with AppController, ILCrashReporter
    [[NSFileManager defaultManager] removeItemAtPath: [NSTemporaryDirectory() stringByAppendingPathComponent:@"PluginCrashed"]
                                               error: nil];
}

+ (int) compareVersion: (NSString *) v1
           withVersion: (NSString *) v2
{
	@try
	{
		NSArray *v1Tokens = [v1 componentsSeparatedByString: @"."];
		NSArray *v2Tokens = [v2 componentsSeparatedByString: @"."];
		int maxLen;
		
		if ( [v1Tokens count] > [v2Tokens count])
			maxLen = [v1Tokens count];
		else
			maxLen = [v2Tokens count];
		
		for (int i = 0; i < maxLen; i++)
		{
			int n1, n2;
			
			n1 = n2 = 0;
			
			if (i < [v1Tokens count])
				n1 = [[v1Tokens objectAtIndex: i] intValue];
			
			if (n1 <= 0)
				[NSException raise: @"compareVersion raised" format: @"compareVersion raised"];
			
			if (i < [v2Tokens count])
				n2 = [[v2Tokens objectAtIndex: i] intValue];
			
			if (n2 <= 0)
				[NSException raise: @"compareVersion raised" format: @"compareVersion raised"];
			
			if (n1 > n2)
				return 1;

            if (n1 < n2)
				return -1;
		}
		
		return 0;
	}
	@catch (NSException *e)
	{
		return -1;
	}

    return -1;
}

+ (BOOL) isComPACS
{
	if (ComPACSTested == NO)
	{
		ComPACSTested = YES;
		
		if ([[PluginManager installedPlugins] valueForKey:@"ComPACS"])
			isComPACS = YES;
		else
			isComPACS = NO;
	}
	return isComPACS;
}

+ (NSMutableDictionary*) installedPlugins
{
	return installedPlugins;
}

+ (NSMutableDictionary*) installedPluginsInfoDict
{
	return installedPluginsInfoDict;
}

+ (NSMutableDictionary*) fileFormatPlugins
{
	return fileFormatPlugins;
}

+ (NSMutableDictionary*) reportPlugins
{
	return reportPlugins;
}

+ (NSArray*) preProcessPlugins
{
	return preProcessPlugins;
}

+ (NSMenu*) fusionPluginsMenu
{
	return fusionPluginsMenu;
}

+ (NSArray*) fusionPlugins
{
	return fusionPlugins;
}

#ifdef OSIRIX_VIEWER

+(void)sortMenu:(NSMenu*)menu
{
    // [CH] Get an array of all menu items.
    NSArray* items = [menu itemArray];
    [menu removeAllItems];
    // [CH] Sort the array
    items = [items sortedArrayUsingDescriptors:[NSArray arrayWithObjects:[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)], nil]];
    // [CH] ok, now set it back.
    for (NSMenuItem* item in items)
    {
        [menu addItem:item];
        /**
         * [CH] The following code fixes NSPopUpButton's confusion that occurs when
         * we sort this list. NSPopUpButton listens to the NSMenu's add notifications
         * and hides the first item. Sorting this blows it up.
         **/
        if (item.isHidden){
            [item setHidden: false];
        }
    }
}

+ (void) setMenus:(NSMenu*) filtersMenu
                 :(NSMenu*) roisMenu
                 :(NSMenu*) othersMenu
                 :(NSMenu*) dbMenu
{
    [filtersMenu removeAllItems];
    [roisMenu removeAllItems];
    [othersMenu removeAllItems];
    [dbMenu removeAllItems];

    // "pluginsDict"

    NSEnumerator *enumerator = [installedPluginsInfoDict objectEnumerator];
	NSBundle *plugin;
	
	while ((plugin = [enumerator nextObject]))
	{
		NSString *pluginName = [[plugin infoDictionary] objectForKey:PINFO_CF_BUNDLE_EXE];
		NSString *pluginType = [[plugin infoDictionary] objectForKey:PINFO_TYPE];
		NSArray  *menuTitles = [[plugin infoDictionary] objectForKey:PINFO_MENU_TITLES];
		
        [PluginManager startProtectForCrashWithPath: [plugin bundlePath]];
        
		if (menuTitles)
		{
			if ([menuTitles count] > 1)
			{
				// Create a sub menu item
				NSMenu  *subMenu = [[[NSMenu alloc] initWithTitle: pluginName] autorelease];
				
				for (NSString *menuTitle in menuTitles)
				{
					NSMenuItem *item;
					
					if ([menuTitle isEqual:PINFO_MENU_ITEM_SEPARATOR])
					{
						item = [NSMenuItem separatorItem];
					}
					else
					{
						item = [[[NSMenuItem alloc] init] autorelease];
						[item setTitle:menuTitle];

						if ([pluginType rangeOfString: PTYPE_FUSION_FILTER].location != NSNotFound)
						{
							[fusionPlugins addObject:[item title]];
							[item setAction:@selector(endBlendingType:)];
						}
						else if ([pluginType rangeOfString: PTYPE_DATABASE].location != NSNotFound ||
                                 [pluginType rangeOfString: PTYPE_REPORT].location != NSNotFound)
						{
							[item setTarget: [BrowserController currentBrowser]];	//  browserWindow responds to DB plugins
							[item setAction:@selector(executeFilterDB:)];
						}
						else
						{
							[item setTarget:nil];	// FIRST RESPONDER !
							[item setAction:@selector(executeFilter:)];
						}
 					}
					
					[subMenu insertItem:item atIndex:[subMenu numberOfItems]];
				}
				
				id subMenuItem;
				
				if ([pluginType rangeOfString: PTYPE_IMAGE_FILTER].location != NSNotFound)
				{
					if ([filtersMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [filtersMenu insertItemWithTitle:pluginName action:nil keyEquivalent:@"" atIndex:[filtersMenu numberOfItems]];
						[filtersMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				}
				else if ([pluginType rangeOfString: PTYPE_ROI_TOOL].location != NSNotFound)
				{
					if ([roisMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [roisMenu insertItemWithTitle:pluginName action:nil keyEquivalent:@"" atIndex:[roisMenu numberOfItems]];
						[roisMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				}
				else if ([pluginType rangeOfString: PTYPE_FUSION_FILTER].location != NSNotFound)
				{
					if ([fusionPluginsMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [fusionPluginsMenu insertItemWithTitle:pluginName action:nil keyEquivalent:@"" atIndex:[fusionPluginsMenu numberOfItems]];
						[fusionPluginsMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				}
				else if ([pluginType rangeOfString: PTYPE_DATABASE].location != NSNotFound)
				{
					if ([dbMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [dbMenu insertItemWithTitle:pluginName action:nil keyEquivalent:@"" atIndex:[dbMenu numberOfItems]];
						[dbMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				} 
				else
				{
					if ([othersMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [othersMenu insertItemWithTitle:pluginName action:nil keyEquivalent:@"" atIndex:[othersMenu numberOfItems]];
						[othersMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				}
                
                [subMenuItem setRepresentedObject:plugin];
			}
			else
			{
				// Create a single menu item
				NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
				
				[item setTitle: [menuTitles objectAtIndex: 0]];	//pluginName];
                [item setRepresentedObject:plugin];
				
				if ([pluginType rangeOfString: PTYPE_FUSION_FILTER].location != NSNotFound)
				{
					[fusionPlugins addObject:[item title]];
					[item setAction:@selector(endBlendingType:)];
				}
				else if ([pluginType rangeOfString: PTYPE_DATABASE].location != NSNotFound ||
                         [pluginType rangeOfString: PTYPE_REPORT].location != NSNotFound)
				{
					[item setTarget:[BrowserController currentBrowser]];	//  browserWindow responds to DB plugins
					[item setAction:@selector(executeFilterDB:)];
				}
				else
				{
					[item setTarget:nil];	// FIRST RESPONDER !
					[item setAction:@selector(executeFilter:)];
				}
				
                if ([pluginType rangeOfString: PTYPE_IMAGE_FILTER].location != NSNotFound) {
					[filtersMenu insertItem:item atIndex:[filtersMenu numberOfItems]];
                }
                else if ([pluginType rangeOfString: PTYPE_ROI_TOOL].location != NSNotFound) {
					[roisMenu insertItem:item atIndex:[roisMenu numberOfItems]];
                }
                else if ([pluginType rangeOfString: PTYPE_FUSION_FILTER].location != NSNotFound) {
					[fusionPluginsMenu insertItem:item atIndex:[fusionPluginsMenu numberOfItems]];
                }
                else if ([pluginType rangeOfString: PTYPE_DATABASE].location != NSNotFound) {
					[dbMenu insertItem:item atIndex:[dbMenu numberOfItems]];
                }
                else {
					[othersMenu insertItem:item atIndex:[othersMenu numberOfItems]];
                }
			}
		}
        
        [PluginManager endProtectForCrash];
	} // while
	
    // Define empty menus if necessary

    if ([filtersMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)]; 
		
		[filtersMenu insertItem:item atIndex:0];
	}
	
	if ([roisMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)];
		
		[roisMenu insertItem:item atIndex:0];
	}
	
	if ([othersMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)];
		
		[othersMenu insertItem:item atIndex:0];
	}
	
	if ([fusionPluginsMenu numberOfItems] <= 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)];
		
		[fusionPluginsMenu removeItemAtIndex: 0];
		[fusionPluginsMenu insertItem:item atIndex:0];
	}
	
	if ( [dbMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)];
		
		[dbMenu insertItem:item atIndex:0];
	}
	
    [PluginManager sortMenu: dbMenu];
    [PluginManager sortMenu: roisMenu];
    [PluginManager sortMenu: filtersMenu];
    [PluginManager sortMenu: othersMenu];
    
    // "plugins"
    // Call each plugin and give it a chance to setup the Menu

    NSEnumerator *pluginEnum = [installedPlugins objectEnumerator];
	PluginFilter *pluginFilter;
	
	while (pluginFilter = [pluginEnum nextObject])
    {
        [PluginManager startProtectForCrashWithFilter: pluginFilter];
        
        @try
        {
            [pluginFilter setMenus];
        }
        @catch (NSException *e)
        {
            NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
        }
        
        [PluginManager endProtectForCrash];
	}
}

- (id)init
{
	if (self = [super init])
	{
		// Set DefaultROINames *before* initializing plugins (which may change these)
		
		NSMutableArray *defaultROINames = [NSMutableArray array];
		
		[defaultROINames addObject:@"ROI 1"];
		[defaultROINames addObject:@"ROI 2"];
		[defaultROINames addObject:@"ROI 3"];
		[defaultROINames addObject:@"ROI 4"];
		[defaultROINames addObject:@"ROI 5"];
		
		[ViewerController setDefaultROINames: defaultROINames];
		
		[PluginManager discoverPlugins];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downloadNext:)
                                                     name:OsirixPluginDownloadInstallDidFinishNotification
                                                   object:nil];
	}
	return self;
}

+ (NSString*) pathResolved:(NSString*) inPath
{
	CFStringRef resolvedPath = nil;
	CFURLRef	url = CFURLCreateWithFileSystemPath(NULL /*allocator*/, (CFStringRef)inPath, kCFURLPOSIXPathStyle, NO /*isDirectory*/);
	if (url != NULL)
    {
		FSRef fsRef;
		if (CFURLGetFSRef(url, &fsRef))
        {
			Boolean targetIsFolder, wasAliased;
			if (FSResolveAliasFile (&fsRef, true /*resolveAliasChains*/, &targetIsFolder, &wasAliased) == noErr && wasAliased)
            {
				CFURLRef resolvedurl = CFURLCreateFromFSRef(NULL /*allocator*/, &fsRef);
				if (resolvedurl != NULL)
                {
					resolvedPath = CFURLCopyFileSystemPath(resolvedurl, kCFURLPOSIXPathStyle);
					CFRelease(resolvedurl);
				}
			}
		}
		CFRelease(url);
	}
	
	if (resolvedPath == nil)
        return inPath;
	else
        return [(NSString *) resolvedPath autorelease];
}

+ (void) releaseInstanciedObjectsOfClass: (Class) theClass
{
    for (int i = 0; i < [preProcessPlugins count]; i++)
    {
        if ([[preProcessPlugins objectAtIndex: i] class] == theClass)
        {
            NSObject *filter = [preProcessPlugins objectAtIndex: i];
            
            if ([filter respondsToSelector: @selector(willUnload)])
                [filter performSelector: @selector(willUnload)];
            
            [preProcessPlugins removeObjectAtIndex: i];
            i--;
        }
    }
    
    for (NSString *key in [installedPlugins allKeys])
    {
        if ([[installedPlugins valueForKey: key] class] == theClass)
        {
            NSObject *filter = [installedPlugins valueForKey: key];
            
            if ([filter respondsToSelector: @selector(willUnload)])
                [filter performSelector: @selector(willUnload)];
            
            [installedPlugins removeObjectForKey: key];
        }
    }
}

+ (void) unloadPlugin: (NSBundle*) bundle
{
//    NSLog( @"--- will unloadplugin: %@", [bundle bundlePath]);
//    @try
//    {
//        [PluginManager startProtectForCrashWithPath: [bundle bundlePath]];
//        
//        Class filterClass = [bundle principalClass];
//                
//        [PluginManager releaseInstanciedObjectsOfClass: filterClass];
//        
//        [PreferencesWindowController removePluginPaneWithBundle: bundle];
//        
//        [pluginsNames removeObjectForKey: [[[bundle bundlePath] lastPathComponent] stringByDeletingPathExtension]];
//        [fileFormatPlugins removeObject: bundle];
//        [pluginsDict removeObject: bundle];
//        [reportPlugins removeObject: bundle];
//        
//        [PluginManager endProtectForCrash];
//        
//        if ([bundle unload] == NO) unload crash, if KVO Bindings is used in a plugin...
//        {
//            NSLog( @"***** failed to unload plugin: %@", [bundle bundlePath]);
//        }
//        else
//        {
//            for (NSString *key in [pluginsBundleDictionary allKeys])
//            {
//                if ([pluginsBundleDictionary valueForKey: key] == bundle)
//                {
//                    [pluginsBundleDictionary removeObjectForKey: key];
//                    return;
//                }
//            }
//        }
//    }
//    @catch (NSException *e)
//    {
//        NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
//    }
}

+ (void) unloadPluginWithName: (NSString*) name
{
    for (NSBundle *bundle in [pluginsBundleDictionary allValues])
    {
        if ([[[[bundle bundlePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString: name])
            [PluginManager unloadPlugin: bundle];
    }
}

+ (void) loadPluginAtPath: (NSString*) path
{
    NSString *name = [path lastPathComponent];
    path = [path stringByDeletingLastPathComponent];
    
    if (([[name pathExtension] isEqualToString:@"plugin"] ||
         [[name pathExtension] isEqualToString:PLUGIN_EXTENSION]))
    {
        if ([pluginsNames valueForKey: [[name lastPathComponent] stringByDeletingPathExtension]])
        {
            NSLog( @"***** Multiple plugins: %@", [name lastPathComponent]);
            
            if ([name.lastPathComponent isEqualToString: @"UserManual.mieleplugin"] == NO)
            {
                NSString *message = NSLocalizedString(@"Warning! Multiple instances of the same plugin have been found. Only one instance will be loaded. Check the Plugin Manager (Plugins menu) for multiple identical plugins.", nil);
                
                message = [message stringByAppendingFormat:@"\r\r%@", [name lastPathComponent]];
                
                NSRunAlertPanel(NSLocalizedString(@"Plugins", nil),
                                @"%@" ,
                                nil,
                                nil,
                                nil,
                                message);
            }
        }
        else
        {
            [pluginsNames setValue: path
                            forKey: [[name lastPathComponent] stringByDeletingPathExtension]];
            
            @try
            {
                NSString *pathResolved = [PluginManager pathResolved: [path stringByAppendingPathComponent: name]];
                
                [PluginManager startProtectForCrashWithPath: pathResolved];
                
                NSBundle *plugin = [NSBundle bundleWithPath: pathResolved];
                
                if (plugin == nil)
                    NSLog( @"**** Bundle opening failed for plugin: %@", [path stringByAppendingPathComponent:name]);
                else
                {
                    if (![plugin load])
                    {
                        NSLog( @"******* Bundle code loading failed for plugin %@", [path stringByAppendingPathComponent:name]);
                    }
                    else
                    {
                        Class filterClass = [plugin principalClass];
                        
                        if (filterClass)
                        {
                            [pluginsBundleDictionary setObject: plugin forKey: pathResolved];
                            
                            // First try CFBundleVersion
                            NSString *version = [[plugin infoDictionary] valueForKey: (NSString*) kCFBundleVersionKey];
                            
                            // If CFBundleVersion is missing, try CFBundleShortVersionString
                            if (version == nil)
                                version = [[plugin infoDictionary] valueForKey: @"CFBundleShortVersionString"];
                            
                            NSLog( @"Loaded: %@, vers: %@ (%@)", [name stringByDeletingPathExtension], version, path);
                            
                            if (filterClass == NSClassFromString( @"ARGS"))
                                return;
                            
                            if ([[[plugin infoDictionary] objectForKey:PINFO_TYPE] rangeOfString:PTYPE_PRE_PROCESS].location != NSNotFound)
                            {
                                PluginFilter *filter = [filterClass filter];
                                [preProcessPlugins addObject: filter];
                            }
                            else if ([[plugin infoDictionary] objectForKey:PINFO_FILE_FORMATS])
                            {
                                NSEnumerator *enumerator = [[[plugin infoDictionary] objectForKey:PINFO_FILE_FORMATS] objectEnumerator];
                                NSString *fileFormat;
                                while (fileFormat = [enumerator nextObject])
                                {
                                    //we will save the bundle rather than a filter.  Each file decode will require a separate decoder
                                    [fileFormatPlugins setObject:plugin forKey:fileFormat];
                                }
                            }
                            else if ( [filterClass instancesRespondToSelector:@selector(filterImage:)])
                            {
                                NSArray *menuTitles = [[plugin infoDictionary] objectForKey:PINFO_MENU_TITLES];
                                PluginFilter *filter = [filterClass filter];
                                
                                if (menuTitles)
                                {
                                    for (NSString *menuTitle in menuTitles)
                                    {
                                        [installedPlugins setObject:filter forKey:menuTitle];
                                        [installedPluginsInfoDict setObject:plugin forKey:menuTitle];
                                    }
                                }
                                
                                NSArray *toolbarNames = [[plugin infoDictionary] objectForKey:PINFO_TOOLBAR_NAMES];
                                
                                if (toolbarNames)
                                {
                                    for (NSString *toolbarName in toolbarNames)
                                    {
                                        [installedPlugins setObject:filter forKey:toolbarName];
                                        [installedPluginsInfoDict setObject:plugin forKey:toolbarName];
                                    }
                                }
                            }
                            
                            if ([[[plugin infoDictionary] objectForKey:PINFO_TYPE] rangeOfString: PTYPE_REPORT].location != NSNotFound)
                            {
                                [reportPlugins setObject: plugin
                                                  forKey: [[plugin infoDictionary] objectForKey:PINFO_CF_BUNDLE_EXE]];
                            }
                        }
                        else
                            NSLog( @"********* principal class not found for: %@ - %@", name, [plugin principalClass]);
                    }
                }
                
                [PluginManager endProtectForCrash];
            }
            @catch( NSException *e)
            {
                NSLog( @"******** Plugin loading exception: %@", e);
            }
        }
    }
}

+ (void) discoverPlugins
{
	@try
	{
        NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:PINFO_CF_BUNDLE_NAME];

        NSString *appSupport = [NSString stringWithFormat:@"Library/Application Support/%@/", bundleName];
        NSString *appAppStoreSupport = [NSString stringWithFormat:@"Library/Application Support/%@ App/", bundleName];
		NSString *appPath = [[NSBundle mainBundle] builtInPlugInsPath];

        NSString *userAppStorePath = [NSHomeDirectory() stringByAppendingPathComponent:appAppStoreSupport];
		NSString *userPath = [NSHomeDirectory() stringByAppendingPathComponent:appSupport];
		NSString *sysPath = [@"/" stringByAppendingPathComponent:appSupport];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:appPath] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath: appPath
                                      withIntermediateDirectories: YES
                                                       attributes: nil
                                                            error: nil];
        
		if ([[NSFileManager defaultManager] fileExistsAtPath:userPath] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath: userPath
                                      withIntermediateDirectories: YES
                                                       attributes: nil
                                                            error: nil];
        
		if ([[NSFileManager defaultManager] fileExistsAtPath:sysPath] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath: sysPath
                                      withIntermediateDirectories: YES
                                                       attributes: nil
                                                            error: nil];
		
		appSupport = [appSupport stringByAppendingPathComponent :@"Plugins/"];
		appAppStoreSupport = [appAppStoreSupport stringByAppendingPathComponent :@"Plugins/"];
		
		userPath = [NSHomeDirectory() stringByAppendingPathComponent:appSupport];
        userAppStorePath = [NSHomeDirectory() stringByAppendingPathComponent:appAppStoreSupport];
		sysPath = [@"/" stringByAppendingPathComponent:appSupport];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:userPath] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath: userPath
                                      withIntermediateDirectories: YES
                                                       attributes: nil
                                                            error: nil];
        
		if ([[NSFileManager defaultManager] fileExistsAtPath:sysPath] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath: sysPath
                                      withIntermediateDirectories: YES
                                                       attributes: nil
                                                            error: nil];
		
		NSArray* paths = [NSArray arrayWithObjects:
                          [NSNull null],  // [NSNull null] is a placeholder for launch parameters load commands
                          appPath,
                          userPath,
                          userAppStorePath,
                          sysPath,
                          nil];
#ifndef NDEBUG
        NSLog(@"%s %d, discover plugins installed in:<%@>", __FUNCTION__, __LINE__, paths);
#endif

        for (NSBundle *bundle in [pluginsBundleDictionary allValues])
            [PluginManager unloadPlugin: bundle];
        
		[installedPlugins release];
		[installedPluginsInfoDict release];
		[fileFormatPlugins release];
		[preProcessPlugins release];
		[reportPlugins release];
		[fusionPlugins release];
		[fusionPluginsMenu release];
		[pluginsNames  release];
        [pluginsBundleDictionary release];
        
        pluginsBundleDictionary = [[NSMutableDictionary alloc] init];
		installedPlugins = [[NSMutableDictionary alloc] init];
		installedPluginsInfoDict = [[NSMutableDictionary alloc] init];
		fileFormatPlugins = [[NSMutableDictionary alloc] init];
		preProcessPlugins = [[NSMutableArray alloc] initWithCapacity:0];
		reportPlugins = [[NSMutableDictionary alloc] init];
		pluginsNames = [[NSMutableDictionary alloc] init];
		fusionPlugins = [[NSMutableArray alloc] initWithCapacity:0];
		
		fusionPluginsMenu = [[NSMenu alloc] initWithTitle:@""];
		[fusionPluginsMenu insertItemWithTitle:NSLocalizedString(@"Select a fusion plug-in", nil) action:nil keyEquivalent:@"" atIndex:0];
		
		NSLog( @"|||||||||||||||||| Plugins loading START ||||||||||||||||||");
#ifndef MIELE_LIGHT
        NSString *pluginCrash = [[[NSFileManager defaultManager] userApplicationSupportFolderForApp] stringByAppendingPathComponent:@"Plugin_Loading"];
        if ([[NSFileManager defaultManager] fileExistsAtPath: pluginCrash] &&
            ![[NSUserDefaults standardUserDefaults] boolForKey:@"DoNotDeleteCrashingPlugins"])
        {
            NSString *pluginCrashPath = [NSString stringWithContentsOfFile: pluginCrash encoding: NSUTF8StringEncoding error: nil];
            
            int result = NSRunInformationalAlertPanel(NSLocalizedString(@"Miele-LXIV crashed", nil),
                                                      NSLocalizedString(@"Previous crash is maybe related to a plugin.\r\rShould I remove this plugin (%@)?", nil),
                                                      NSLocalizedString(@"Delete Plugin",nil),
                                                      NSLocalizedString(@"Continue",nil),
                                                      nil,
                                                        [pluginCrashPath lastPathComponent]);
            
            if (result == NSAlertDefaultReturn) // Delete Plugin
            {
                NSError *error = nil;
                [[NSFileManager defaultManager] removeItemAtPath: pluginCrashPath error: &error];
                
                if (error)
                    NSLog( @"**** Cannot Delete File : Crashing Plugin Delete Error: %@", error);
            }
            
            [[NSFileManager defaultManager] removeItemAtPath: pluginCrash error: nil];
        }
        
        NSMutableArray* pathsOfPluginsToLoad = [NSMutableArray array];
        for (id path in paths)
            @try {
                NSArray* doNotLoadNames = nil;
                if (![path isKindOfClass:[NSNull class]])
                {
                    doNotLoadNames = [[NSString stringWithContentsOfFile:[path stringByAppendingPathComponent:@"DoNotLoad.txt"]] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                    if ([doNotLoadNames containsObject:@"*"])
                        break;
                }

                NSEnumerator* e = nil;
                if ([path isKindOfClass:[NSString class]])
                {
                    e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
                }
                else if (path == [NSNull null])
                {
                    path = @"/";
                    NSMutableArray* cl = [NSMutableArray array];
                    NSArray* args = [[NSProcessInfo processInfo] arguments];
                    for (NSInteger i = 0; i < [args count]; ++i)
                        if ([[args objectAtIndex:i] isEqualToString:@"--LoadPlugin"] && [args count] > i+1) {
                            [cl addObject:[args objectAtIndex:++i]];
                        }

                    e = [cl objectEnumerator];
                }
                
                NSString* name;
                while (name = [e nextObject])
                    if ([[name pathExtension] isEqualToString:PLUGIN_EXTENSION] &&
                        [doNotLoadNames containsObject:[name stringByDeletingPathExtension]] == NO)
                    {
                        NSString *s = [path stringByAppendingPathComponent:name];
                        [pathsOfPluginsToLoad addObject:[s stringByStandardizingPath]];
                    }
            } @catch (NSException* e) {
                N2LogExceptionWithStackTrace(e);
            }
        
        // some plugins require other plugins to be loaded before them
        for (__block NSInteger i = pathsOfPluginsToLoad.count-1; i >= 0; --i)
        {
            NSBundle* bundle = [NSBundle bundleWithPath:[pathsOfPluginsToLoad objectAtIndex:i]];
            NSString* name = [bundle.infoDictionary objectForKey:PINFO_CF_BUNDLE_NAME];
            if (!name)
                name = [[[pathsOfPluginsToLoad objectAtIndex:i] lastPathComponent] stringByDeletingPathExtension];
//            
            
            // list of requirements
            for (NSString* req in [bundle.infoDictionary objectForKey:PINFO_REQUIREMENTS])
            {
                // make sure they're loaded before this plugin
                NSIndexSet* is = [pathsOfPluginsToLoad indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    NSBundle* bundle = [NSBundle bundleWithPath:obj];
                    NSString* name = [bundle.infoDictionary objectForKey:PINFO_CF_BUNDLE_NAME];
                    if (!name)
                        name = [[obj lastPathComponent] stringByDeletingPathExtension];
                    
                    return [name isEqualToString:req];
                }];
                if (!is.count)
                    NSLog(@"Warning: plugin requirement %@ not available for %@", req, name); // we actually may decide not to load this plugin, since it requires something that apparently isn't available, but hopefully it'll just raise an exception and end up not being loaded...
                [is enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                    if (idx > i) {
                        id o = [[[pathsOfPluginsToLoad objectAtIndex:idx] retain] autorelease];
                        [pathsOfPluginsToLoad removeObjectAtIndex:idx];
                        [pathsOfPluginsToLoad insertObject:o atIndex:i++];
                    }
                }];
            }
        }
        
        for (id path in pathsOfPluginsToLoad)
            [PluginManager loadPluginAtPath:path];
#endif
        NSLog( @"|||||||||||||||||| Plugins loading END ||||||||||||||||||");
	}
	@catch (NSException * e)
	{
        N2LogExceptionWithStackTrace(e);
	}
}

-(void) noPlugins:(id) sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:URL_OSIRIX_PLUGINS]];
}

#pragma mark - Plugin user management

#pragma mark - directories

+ (NSString*)activePluginsDirectoryPath;
{
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:PINFO_CF_BUNDLE_NAME];
    return [NSString stringWithFormat:@"Library/Application Support/%@/Plugins/", bundleName];
}

+ (NSString*)inactivePluginsDirectoryPath;
{
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:PINFO_CF_BUNDLE_NAME];
    return [NSString stringWithFormat:@"Library/Application Support/%@/Plugins Disabled/", bundleName];
}

+ (NSString*)userActivePluginsDirectoryPath;
{
	return [NSHomeDirectory() stringByAppendingPathComponent:[PluginManager activePluginsDirectoryPath]];
}

+ (NSString*)userInactivePluginsDirectoryPath;
{
	return [NSHomeDirectory() stringByAppendingPathComponent:[PluginManager inactivePluginsDirectoryPath]];
}

+ (NSString*)systemActivePluginsDirectoryPath;
{
	NSString *s = @"/";
	return [s stringByAppendingPathComponent:[PluginManager activePluginsDirectoryPath]];
}

+ (NSString*)systemInactivePluginsDirectoryPath;
{
	NSString *s = @"/";
	return [s stringByAppendingPathComponent:[PluginManager inactivePluginsDirectoryPath]];
}

+ (NSString*)appActivePluginsDirectoryPath;
{
	return [[NSBundle mainBundle] builtInPlugInsPath];
}

+ (NSString*)appInactivePluginsDirectoryPath;
{
	NSMutableString *appPath = [NSMutableString stringWithString:[[NSBundle mainBundle] builtInPlugInsPath]];
	[appPath appendString:@" Disabled"];
	return appPath;
}

+ (NSArray*)activeDirectories;
{
	return [NSArray arrayWithObjects:
            [PluginManager userActivePluginsDirectoryPath],
            [PluginManager systemActivePluginsDirectoryPath],
            [PluginManager appActivePluginsDirectoryPath],
            nil];
}

+ (NSArray*)inactiveDirectories;
{
	return [NSArray arrayWithObjects:
            [PluginManager userInactivePluginsDirectoryPath],
            [PluginManager systemInactivePluginsDirectoryPath],
            [PluginManager appInactivePluginsDirectoryPath],
            nil];
}

#pragma mark - activation

//- (BOOL)pluginIsActiveForName:(NSString*)pluginName;
//{
//	NSMutableArray *paths = [NSMutableArray array];
//	[paths addObjectsFromArray:[self activeDirectories]];
//	
//	NSEnumerator *pathEnum = [paths objectEnumerator];
//    NSString *path;
//	while(path=[pathEnum nextObject])
//	{
//		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
//		NSString *name;
//		while(name = [e nextObject])
//		{
//			if ([[name stringByDeletingPathExtension] isEqualToString:pluginName])
//			{
//				return YES;
//			}
//		}
//	}
//	
//	return NO;
//}

+ (void)movePluginFromPath:(NSString*)sourcePath
                    toPath:(NSString*)destinationPath;
{
	if ([sourcePath isEqualToString:destinationPath])
        return;
	
    if (![[NSFileManager defaultManager] fileExistsAtPath:[destinationPath stringByDeletingLastPathComponent]])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:[destinationPath stringByDeletingLastPathComponent]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }

    NSMutableArray *args = [NSMutableArray array];
	[args addObject:@"-f"];
    [args addObject:sourcePath];
    [args addObject:destinationPath];

	[[BLAuthentication sharedInstance] executeCommand:@"/bin/mv" withArgs:args];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: destinationPath] == NO)
    {
        NSMutableArray *args = [NSMutableArray array];
        [args addObject:@"-f"];
        [args addObject:@"-R"];
        [args addObject:sourcePath];
        [args addObject:destinationPath];
        
        [[BLAuthentication sharedInstance] executeCommand:@"/bin/cp" withArgs:args];
    }
}

+ (void)activatePluginWithName:(NSString*)pluginName;
{
	NSMutableArray *activePaths = [NSMutableArray arrayWithArray:[PluginManager activeDirectories]];
	NSMutableArray *inactivePaths = [NSMutableArray arrayWithArray:[PluginManager inactiveDirectories]];
	
	NSEnumerator *activePathEnum = [activePaths objectEnumerator];
    NSString *activePath;
    NSString *inactivePath;
    
	for (inactivePath in inactivePaths)
	{
		activePath = [activePathEnum nextObject];
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:inactivePath] objectEnumerator];
		NSString *name;
		while(name = [e nextObject])
		{
			if ([[name stringByDeletingPathExtension] isEqualToString:pluginName])
			{
				NSString *sourcePath = [NSString stringWithFormat:@"%@/%@", inactivePath, name];
				NSString *destinationPath = [NSString stringWithFormat:@"%@/%@", activePath, name];
				[PluginManager movePluginFromPath:sourcePath toPath:destinationPath];
			}
		}
	}
    
    if (!gPluginsAlertAlreadyDisplayed)
        NSRunInformationalAlertPanel(NSLocalizedString(@"Plugins", @""),
                                     NSLocalizedString( @"Restart OsiriX to apply the changes to the plugins.", @""),
                                     NSLocalizedString(@"OK", @""),
                                     nil,
                                     nil);
    gPluginsAlertAlreadyDisplayed = YES;
}

+ (void)deactivatePluginWithName:(NSString*)pluginName;
{
//    [PluginManager unloadPluginWithName: pluginName];
    
	NSMutableArray *activePaths = [NSMutableArray arrayWithArray:[PluginManager activeDirectories]];
	NSMutableArray *inactivePaths = [NSMutableArray arrayWithArray:[PluginManager inactiveDirectories]];
	
    NSString *activePath;
	NSEnumerator *inactivePathEnum = [inactivePaths objectEnumerator];
    NSString *inactivePath;
	
	for (activePath in activePaths)
	{
		inactivePath = [inactivePathEnum nextObject];
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:activePath] objectEnumerator];
		NSString *name;
		while(name = [e nextObject])
		{
			if ([[name stringByDeletingPathExtension] isEqualToString:pluginName])
			{
				BOOL isDir = YES;
				if (![[NSFileManager defaultManager] fileExistsAtPath:inactivePath isDirectory:&isDir] && isDir)
					[PluginManager createDirectory:inactivePath];

                //	[[NSFileManager defaultManager] createDirectoryAtPath:inactivePath withIntermediateDirectories:YES attributes:nil error:nil];
				NSString *sourcePath = [NSString stringWithFormat:@"%@/%@", activePath, name];
				NSString *destinationPath = [NSString stringWithFormat:@"%@/%@", inactivePath, name];
				[PluginManager movePluginFromPath:sourcePath toPath:destinationPath];
			}
		}
	}
    
    if (!gPluginsAlertAlreadyDisplayed)
        NSRunInformationalAlertPanel(NSLocalizedString(@"Plugins", @""),
                                     NSLocalizedString( @"Restart OsiriX to apply the changes to the plugins.", @""),
                                     NSLocalizedString(@"OK", @""),
                                     nil,
                                     nil);
    gPluginsAlertAlreadyDisplayed = YES;
}

+ (void)changeAvailabilityOfPluginWithName:(NSString*)pluginName to:(NSString*)availability;
{
    NSArray *availabilities = [PluginManager availabilities];
    
#if 0 //def MACAPPSTORE
    if ([availability isEqualTo:[availabilities objectAtIndex:0]] == NO)  // not user
    {
        NSRunCriticalAlertPanel(NSLocalizedString(@"Plugin",nil),
                                NSLocalizedString(@"You cannot move the plugin to another location with this version of OsiriX.", nil),
                                NSLocalizedString(@"OK",nil),
                                nil,
                                nil);
    }
#endif
    
	NSMutableArray *paths = [NSMutableArray array];
	[paths addObjectsFromArray:[PluginManager activeDirectories]];
	[paths addObjectsFromArray:[PluginManager inactiveDirectories]];

	NSEnumerator *pathEnum = [paths objectEnumerator];
    NSString *path;
	NSString *completePluginPath = nil;
	BOOL found = NO;
	
	while((path = [pathEnum nextObject]) && !found)
	{
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString *name;
		while((name = [e nextObject]) && !found)
		{
			if ([[name stringByDeletingPathExtension] isEqualToString:pluginName])
			{
				completePluginPath = [NSString stringWithFormat:@"%@/%@", path, name];
				found = YES;
			}
		}
	}
	
	NSString *directory = [completePluginPath stringByDeletingLastPathComponent];
	NSMutableString *newDirectory = [NSMutableString stringWithString:@""];
	
	
	if ([availability isEqualTo:[availabilities objectAtIndex:0]])  // user
	{
		[newDirectory setString:[PluginManager userActivePluginsDirectoryPath]];
	}
	else if (availabilities.count >= 1 && [availability isEqualTo:[availabilities objectAtIndex:1]])  // system
	{
		[newDirectory setString:[PluginManager systemActivePluginsDirectoryPath]];
	}
	else if (availabilities.count >= 2 && [availability isEqualTo:[availabilities objectAtIndex:2]]) // app bundle
	{
		[newDirectory setString:[PluginManager appActivePluginsDirectoryPath]];
	}

    [newDirectory setString:[newDirectory stringByDeletingLastPathComponent]]; // remove /Plugins/
	[newDirectory setString:[newDirectory stringByAppendingPathComponent:[directory lastPathComponent]]]; // add /Plugins/ or /Plugins (off)/
	
	NSMutableString *newPluginPath = [NSMutableString stringWithString:@""];
	[newPluginPath setString:[newDirectory stringByAppendingPathComponent:[completePluginPath lastPathComponent]]];
	
	[PluginManager movePluginFromPath:completePluginPath toPath:newPluginPath];
}

+ (void)createDirectory:(NSString*)directoryPath;
{
	BOOL isDir = YES;
	BOOL directoryCreated = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:&isDir] && isDir)
		directoryCreated = [[NSFileManager defaultManager] createDirectoryAtPath: directoryPath
                                                     withIntermediateDirectories: YES
                                                                      attributes: nil
                                                                           error: nil];

	if (!directoryCreated)
	{
	    NSMutableArray *args = [NSMutableArray array];
		[args addObject:directoryPath];
		[[BLAuthentication sharedInstance] executeCommand:@"/bin/mkdir" withArgs:args];
	}
}

#pragma mark - Instalation

+ (void) installPluginFromPath: (NSString*) path
{
    // move the plugin package into the plugins (active) directory
    NSString *destinationDirectory = nil;
    NSString *destinationPath = nil;
    
    NSMutableDictionary *active = [NSMutableDictionary dictionary];
	NSMutableDictionary *availabilities = [NSMutableDictionary dictionary];
	
    NSString *pluginBundleName = [[path lastPathComponent] stringByDeletingPathExtension];
    
    for (NSDictionary *plug in [PluginManager pluginsList])
    {
        if ([pluginBundleName isEqualToString: [plug objectForKey:@"name"]])
        {
            [availabilities setObject: [plug objectForKey:@"availability"] forKey:path];
            [active setObject: [plug objectForKey:@"active"] forKey:path];
        }
    }
    
    NSString *availability = [availabilities objectForKey: path];
    BOOL isActive = [[active objectForKey:path] boolValue];
    
    if (!availability)
        isActive = YES;
    
    if ([availability isEqualToString:[[PluginManager availabilities] objectAtIndex:0]])  // user
    {
        if (isActive)
            destinationDirectory = [PluginManager userActivePluginsDirectoryPath];
        else
            destinationDirectory = [PluginManager userInactivePluginsDirectoryPath];
    }
    else if ([availability isEqualToString:[[PluginManager availabilities] objectAtIndex:1]]) //system
    {
        if (isActive)
            destinationDirectory = [PluginManager systemActivePluginsDirectoryPath];
        else
            destinationDirectory = [PluginManager systemInactivePluginsDirectoryPath];
    }
    else if ([availability isEqualToString:[[PluginManager availabilities] objectAtIndex:2]]) // app bundle
    {
        if (isActive)
            destinationDirectory = [PluginManager appActivePluginsDirectoryPath];
        else
            destinationDirectory = [PluginManager appInactivePluginsDirectoryPath];
    }
    else
    {
        if (isActive)
            destinationDirectory = [PluginManager userActivePluginsDirectoryPath];
        else
            destinationDirectory = [PluginManager userInactivePluginsDirectoryPath];
    }
    
    destinationPath = [destinationDirectory stringByAppendingPathComponent: [path lastPathComponent]];
    
    // delete the plugin if it already exists.
    [PluginManager deletePluginWithName: [path lastPathComponent]];
    
    // move the new plugin to the plugin folder				
    [PluginManager movePluginFromPath: path toPath: destinationPath];
    
//    // load the plugin - The User has to restart
//    [PluginManager loadPluginAtPath: destinationPath];
}

#pragma mark - Deletion

+ (NSString*) deletePluginWithName:(NSString*)pluginName;
{
	return [PluginManager deletePluginWithName: pluginName availability: nil isActive: YES];
}

+ (NSString*) deletePluginWithName:(NSString*)pluginName availability: (NSString*) availability isActive:(BOOL) isActive
{
    pluginName = [pluginName stringByDeletingPathExtension];
    
    // First unload the plugin, if currently running
//    [PluginManager unloadPluginWithName: pluginName];
    
	NSMutableArray *pluginsPaths = [NSMutableArray arrayWithArray:[PluginManager activeDirectories]];
	[pluginsPaths addObjectsFromArray:[PluginManager inactiveDirectories]];
	
    NSString *path, *returnPath = nil;
	NSString *trashDir = [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"];
	
	NSString *directory = nil;
	NSArray *availabilities = [PluginManager availabilities];
	if ([availability isEqualToString:[availabilities objectAtIndex:0]])  // user
	{
		if (isActive)
			directory = [PluginManager userActivePluginsDirectoryPath];
		else
			directory = [PluginManager userInactivePluginsDirectoryPath];
	}
	else if (availabilities.count >= 1 && [availability isEqualToString:[availabilities objectAtIndex:1]])  // system
	{
		if (isActive)
			directory = [PluginManager systemActivePluginsDirectoryPath];
		else
			directory = [PluginManager systemInactivePluginsDirectoryPath];
	}
	else if (availabilities.count >= 2 && [availability isEqualToString:[availabilities objectAtIndex:2]])  // app bundle
	{
		if (isActive)
			directory = [PluginManager appActivePluginsDirectoryPath];
		else
			directory = [PluginManager appInactivePluginsDirectoryPath];
	}
	
	for (path in pluginsPaths)
	{
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString *name;
		while(name = [e nextObject])
		{
			if ([[name stringByDeletingPathExtension] isEqualToString: [pluginName stringByDeletingPathExtension]] && (directory == nil || [directory isEqualTo: path]))
			{
				NSInteger tag = 0;
				[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                             source:path
                                                        destination:trashDir
                                                              files:[NSArray arrayWithObject:name]
                                                                tag:&tag];
				if (tag!=0)
				{
					NSLog( @"performFileOperation:NSWorkspaceRecycleOperation failed, will us mv");
					
					NSMutableArray *args = [NSMutableArray array];
					[args addObject:@"-f"];
					[args addObject:[NSString stringWithFormat:@"%@/%@", path, name]];
					[args addObject:[NSString stringWithFormat:@"%@/%@", trashDir, name]];
					[[BLAuthentication sharedInstance] executeCommand:@"/bin/mv" withArgs:args];

				}
				
				returnPath = path;
				
//				// delete
//				BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", path, name] error:nil];
//				if (!deleted)
//				{
//					NSMutableArray *args = [NSMutableArray array];
//					[args addObject:@"-r"];
//					[args addObject:[NSString stringWithFormat:@"%@/%@", path, name]];
//					[[BLAuthentication sharedInstance] executeCommand:@"/bin/rm" withArgs:args];
//				}
			}
		}
	}
	
    if (!gPluginsAlertAlreadyDisplayed)
        NSRunInformationalAlertPanel(NSLocalizedString(@"Plugins", @""),
                                     NSLocalizedString( @"Restart OsiriX to apply the changes to the plugins.", @""),
                                     NSLocalizedString(@"OK", @""),
                                     nil,
                                     nil);
    gPluginsAlertAlreadyDisplayed = YES;
    
	return returnPath;
}

#pragma mark - plugins

NSInteger sortPluginArray(id plugin1, id plugin2, void *context)
{
    NSString *name1 = [plugin1 objectForKey:@"name"];
    NSString *name2 = [plugin2 objectForKey:@"name"];
    
	return [name1 compare:name2 options: NSCaseInsensitiveSearch];
}

+ (NSArray*)pluginsList;
{
	NSString *userActivePath = [PluginManager userActivePluginsDirectoryPath];
	NSString *userInactivePath = [PluginManager userInactivePluginsDirectoryPath];
	NSString *sysActivePath = [PluginManager systemActivePluginsDirectoryPath];
	NSString *sysInactivePath = [PluginManager systemInactivePluginsDirectoryPath];

//	NSArray *paths = [NSArray arrayWithObjects:userActivePath, userInactivePath, sysActivePath, sysInactivePath, nil];
	
	NSMutableArray *paths = [NSMutableArray array];
	[paths addObjectsFromArray:[PluginManager activeDirectories]];
	[paths addObjectsFromArray:[PluginManager inactiveDirectories]];
    
    NSString *path;
	
    NSMutableArray *plugins = [NSMutableArray array];
	
    for (path in paths)
	{
//		BOOL active = ([path isEqualToString:userActivePath] || [path isEqualToString:sysActivePath]);
//		BOOL allUsers = ([path isEqualToString:sysActivePath] || [path isEqualToString:sysInactivePath]);
		BOOL active = [[PluginManager activeDirectories] containsObject:path];
		BOOL allUsers = ([path isEqualToString:sysActivePath] ||
                         [path isEqualToString:sysInactivePath] ||
                         [path isEqualToString:[PluginManager appActivePluginsDirectoryPath]] ||
                         [path isEqualToString:[PluginManager appInactivePluginsDirectoryPath]]);
		
		NSString *availability = nil;
		if ([path isEqualToString:sysActivePath] ||
            [path isEqualToString:sysInactivePath])
        {
			availability = [[PluginManager availabilities] objectAtIndex:1];    // system
        }
		else if ([path isEqualToString:[PluginManager appActivePluginsDirectoryPath]] ||
                 [path isEqualToString:[PluginManager appInactivePluginsDirectoryPath]])
        {
			availability = [[PluginManager availabilities] objectAtIndex:2];    // app bundle
        }
		else if ([path isEqualToString:userActivePath] ||
                 [path isEqualToString:userInactivePath])
        {
			availability = [[PluginManager availabilities] objectAtIndex:0];    // user
        }
		
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString *name;
		while(name = [e nextObject])
		{
			if ([[name pathExtension] isEqualToString:@"plugin"] ||
                [[name pathExtension] isEqualToString:PLUGIN_EXTENSION])
			{
//				NSBundle *plugin = [NSBundle bundleWithPath:[PluginManager pathResolved:[path stringByAppendingPathComponent:name]]];
//				if (filterClass = [plugin principalClass])	
				{					
					NSMutableDictionary *pluginDescription = [NSMutableDictionary dictionaryWithCapacity:3];
					[pluginDescription setObject:[name stringByDeletingPathExtension] forKey:@"name"];
					[pluginDescription setObject:[NSNumber numberWithBool:active] forKey:@"active"];
					[pluginDescription setObject:[NSNumber numberWithBool:allUsers] forKey:@"allUsers"];
						
					[pluginDescription setObject:availability forKey:@"availability"];
					
					// plugin version
					
					// taking the "version" through NSBundle is a BAD idea: Cocoa keeps the NSBundle in cache... thus for a same path you'll always have the same version
					
					NSURL *bundleURL = [NSURL fileURLWithPath:[PluginManager pathResolved:[path stringByAppendingPathComponent:name]]];
					CFDictionaryRef bundleInfoDict = CFBundleCopyInfoDictionaryInDirectory((CFURLRef)bundleURL);
								
					CFStringRef versionString = nil;
					if (bundleInfoDict)
					{
						versionString = (CFStringRef)CFDictionaryGetValue(bundleInfoDict, CFSTR("CFBundleVersion"));
					
						if (versionString == nil)
							versionString = (CFStringRef)CFDictionaryGetValue(bundleInfoDict, CFSTR("CFBundleShortVersionString"));
					}
					
					NSString *pluginVersion;
					if (versionString)
						pluginVersion = (NSString*)versionString;
					else
						pluginVersion = @"";
						
					[pluginDescription setObject:pluginVersion forKey:@"version"];
					
					if (bundleInfoDict)
						CFRelease( bundleInfoDict);
					
					// plugin description dictionary
					[plugins addObject:pluginDescription];
				}
			}
		}
	}
	NSArray *sortedPlugins = [plugins sortedArrayUsingFunction:sortPluginArray context:NULL];
	return sortedPlugins;
}

+ (NSArray*)availabilities;
{
	return [NSArray arrayWithObjects:
            NSLocalizedString(@"Current user", nil),
            NSLocalizedString(@"All users", nil),
            NSLocalizedString(@"Miele-LXIV bundle", nil), nil];
}

#pragma mark - auto update

- (IBAction)checkForPluginUpdates:(id)sender
{
	NSURL				*url;
	NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
	
    [NSThread currentThread].name = @"Check for plugins updates";
    
	[NSThread sleepForTimeInterval: 10];
	
	url = [NSURL URLWithString:URL_PLUGIN_LIST];
	
	if (url)
	{
		NSMutableArray *onlinePlugins = [NSMutableArray arrayWithContentsOfURL:url];
		NSArray *installedPlugins = [PluginManager pluginsList];
		
		NSMutableArray *pluginsToUpdate = [NSMutableArray array];
		
		for (NSDictionary *installedPlugin in installedPlugins)
		{
			NSString *pluginName = [installedPlugin valueForKey:@"name"];
			
			NSDictionary *onlinePlugin = nil;
			for (NSDictionary *plugin in onlinePlugins)
			{
                NSString *path = [[plugin valueForKey:@"download_url"] valueForKey:@"path"];
				NSString *name = [[path lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				name = [name stringByDeletingPathExtension]; // removes the .zip extension
				name = [name stringByDeletingPathExtension]; // removes the .mieleplugin extension
				
				if ([pluginName isEqualToString:name])
				{
					onlinePlugin = plugin;
					break;
				}
			}
			
			if (onlinePlugin)
			{
				NSString *currVersion = [installedPlugin objectForKey:@"version"];
				NSString *onlineVersion = [onlinePlugin objectForKey:@"version"];
                NSLog(@"currVersion:%@, onlineVersion:%@", currVersion, onlineVersion);
				
				if (currVersion &&
                    onlineVersion &&
                    [currVersion length] > 0 &&
                    [currVersion length] > 0)
				{
					if ([currVersion isEqualToString:onlineVersion] == NO &&
                        [PluginManager compareVersion: currVersion withVersion: onlineVersion] < 0)
					{
						NSLog( @"PLUGIN UPDATE NEEDED -------> current vers: %@ versus online vers: %@ - %@", currVersion, onlineVersion, pluginName);
						NSMutableDictionary *modifiedOnlinePlugin = [NSMutableDictionary dictionaryWithDictionary:onlinePlugin];
						[modifiedOnlinePlugin setObject:pluginName forKey:@"name"];
						[pluginsToUpdate addObject:modifiedOnlinePlugin];
					}
				}
				[onlinePlugins removeObject:onlinePlugin];
			}
		}
		//ici
		if ([pluginsToUpdate count])
		{
			NSString *title;
			NSMutableString *message = [NSMutableString string];
			
			if ([pluginsToUpdate count]==1)
			{
				title = NSLocalizedString(@"Plugin Update Available", @"");
				[message appendFormat:NSLocalizedString(@"A new version of the plugin \"%@\" is available.", @""), [[pluginsToUpdate objectAtIndex:0] objectForKey:@"name"]];
			}
			else
			{
				title = NSLocalizedString(@"Plugin Updates Available", @"");
				[message appendString:NSLocalizedString(@"New versions of the following plugins are available:\n", @"")];
				for (NSDictionary *plugin in pluginsToUpdate)
				{
					[message appendFormat:@"%@, ", [plugin objectForKey:@"name"]];
				}
				message = [NSMutableString stringWithString:[message substringToIndex:[message length]-2]];
			}
								
			NSDictionary *messageDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:title, message, pluginsToUpdate, nil] forKeys:[NSArray arrayWithObjects:@"title", @"body", @"plugins", nil]];
			
			[self performSelectorOnMainThread:@selector(displayUpdateMessage:) withObject:messageDictionary waitUntilDone: NO];
		}
	}
	
	[pool release];
}

- (void)displayUpdateMessage:(NSDictionary*)messageDictionary;
{
	[messageDictionary retain];

	NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
	
		int button = NSRunAlertPanel([messageDictionary objectForKey:@"title"],
                                     @"%@",
                                     NSLocalizedString(@"Download", @""),
                                     NSLocalizedString( @"Cancel", @""),
                                     nil,
                                     [messageDictionary objectForKey:@"body"]);
			
		if (NSOKButton == button)
		{
			startedUpdateProcess = YES;
			PluginManagerController *pluginManagerController = [[BrowserController currentBrowser] pluginManagerController];

			if (pluginManagerController)
			{
				NSArray *pluginsToDownload = [messageDictionary objectForKey:@"plugins"];
				self.downloadQueue = [NSMutableArray arrayWithArray:pluginsToDownload];
				
				NSLog(@"Download Plugin : %@", [[pluginsToDownload objectAtIndex:0] objectForKey:@"download_url"]);
				[pluginManagerController setDownloadUrlDict:[[pluginsToDownload objectAtIndex:0] objectForKey:@"download_url"]];
				[pluginManagerController download:self];
			}
		}
		else
            startedUpdateProcess = NO;
	
	[pool release];
	
	[messageDictionary release];
}

-(void)downloadNext:(NSNotification*)notification;
{
	if (!startedUpdateProcess)
        return;
	
	if ([downloadQueue count]>1)
	{
		[downloadQueue removeObjectAtIndex:0];

		PluginManagerController *pluginManagerController = [[BrowserController currentBrowser] pluginManagerController];

		NSLog(@"Download Plugin : %@", [[downloadQueue objectAtIndex:0] objectForKey:@"download_url"]);
		[pluginManagerController setDownloadUrlDict:[[downloadQueue objectAtIndex:0] objectForKey:@"download_url"]];
		[pluginManagerController download:self];
	}
	else
	{
        if (!gPluginsAlertAlreadyDisplayed)
            NSRunInformationalAlertPanel(NSLocalizedString(@"Plugin Update Completed", @""),
                                         NSLocalizedString(@"All your plugins are now up to date. Restart OsiriX to use the new or updated plugins.", @""),
                                         NSLocalizedString(@"OK", @""),
                                         nil,
                                         nil);
		gPluginsAlertAlreadyDisplayed = YES;
        
        startedUpdateProcess = NO;
	}
}

#endif

@end
