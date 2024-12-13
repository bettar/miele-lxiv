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

#import "PluginManagerController.h"
#import "WaitRendering.h"
#import "Notifications.h"
#import "PreferencesWindowController.h"
#import "ThreadsManager.h"
#import "NSThread+N2.h"
#import "AppController.h"

#import "url.h"
#import "tmp_locations.h"
#import "alertTransition.h"

#ifdef SUBMIT_PLUGIN_WITH_MAIL_APP
#import <Message/NSMailDelivery.h>
#endif

static NSArray *CachedPluginsList = nil;
static NSDate *CachedPluginsListDate = nil;

@implementation PluginsTableView

- (void)keyDown:(NSEvent *)event
{
    if ([[event characters] length] == 0)
        return;
    
	unichar c = [[event characters] characterAtIndex:0];
	if (( c == NSDeleteFunctionKey || c == NSDeleteCharacter || c == NSBackspaceCharacter || c == NSDeleteCharFunctionKey) && [self selectedRow] >= 0 && [self numberOfRows] > 0)
		[(PluginManagerController*)[self delegate] delete:self];
	else
		 [super keyDown:event];
}

@end

@implementation PluginManagerController

- (void) WebViewProgressStartedNotification: (NSNotification*) n
{
    [statusProgressIndicator setHidden: NO];
	[statusProgressIndicator startAnimation: self];
    
    [[self window] display];
}

- (void) WebViewProgressFinishedNotification: (NSNotification*) n
{
    [statusProgressIndicator setHidden: YES];
	[statusProgressIndicator stopAnimation: self];
    
    [[self window] display];
}

- (id)init
{
	self = [super initWithWindowNibName:@"PluginManager"];
	
    downloadingPlugins = [[NSMutableDictionary dictionary] retain];
    
	plugins = [[NSMutableArray arrayWithArray:[PluginManager pluginsList]] retain];
	
	pluginsListURLs = [[NSArray arrayWithObjects:
                        URL_PLUGIN_LIST,
                        URL_PLUGIN_LIST_MIRROR1,
                        nil] retain];

	NSRect windowFrame = [[self window] frame];
	[[self window] setFrame:NSMakeRect(windowFrame.origin.x,windowFrame.origin.y,800,900) display:YES];
	 
	[webView setPolicyDelegate:self];
	
	[statusTextField setHidden:YES];
	[statusProgressIndicator setHidden:YES];
	
	// deactivate the back/forward options in the webView's contextual menu
	[[webView backForwardList] setCapacity:0];
	
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(WebViewProgressStartedNotification:)
                                                 name: WebViewProgressStartedNotification
                                               object: webView];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(WebViewProgressFinishedNotification:)
                                                 name: WebViewProgressFinishedNotification
                                               object: webView];
        
	return self;
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
    if ([AppController isFDACleared])
    {
        NSRunCriticalAlertPanel2(NSLocalizedString( @"Important Notice", nil),
                                NSLocalizedString( @"Plugins are not certified for primary diagnosis in medical imaging, unless specifically written by the plugin author(s).", nil),
                                NSLocalizedString( @"OK", nil),
                                nil,
                                nil);
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self]; 
     
	[plugins release];
	[pluginsListURLs release];
	[downloadUrlDict release];
    [downloadingPlugins release];
	
	[super dealloc];
}

#pragma mark - installed

- (NSMutableArray*)plugins;
{
	return plugins;
}

- (NSArray*)availabilities;
{
	return [PluginManager availabilities];
}

- (IBAction)modifiyActivation:(id)sender
{
	NSArray *pluginsList = [pluginsArrayController arrangedObjects];
	NSString *pluginName = [[pluginsList objectAtIndex:[pluginTable clickedRow]] objectForKey:@"name"];
	BOOL pluginIsActive = [[[pluginsList objectAtIndex:[pluginTable clickedRow]] objectForKey:@"active"] boolValue];

	if (!pluginIsActive)
	{
		[PluginManager deactivatePluginWithName:pluginName];
	}
	else
	{
		[PluginManager activatePluginWithName:pluginName];
	}
	
	[self refreshPluginList];
	[pluginTable selectRowIndexes: [NSIndexSet indexSetWithIndex: [pluginTable clickedRow]] byExtendingSelection:NO];
}

- (IBAction)delete:(id)sender
{
	if (NSRunInformationalAlertPanel2(NSLocalizedString(@"Delete a plugin", nil),
                                     NSLocalizedString(@"Are you sure you want to delete the selected plugin?", nil),
                                     NSLocalizedString(@"OK",nil),
                                     NSLocalizedString(@"Cancel",nil),
                                     nil) == NSAlertDefaultReturn2)
	{
		NSArray *pluginsList = [pluginsArrayController arrangedObjects];
		NSString *pluginName = [[pluginsList objectAtIndex:[pluginTable selectedRow]] objectForKey:@"name"];
		NSString *availability = [[pluginsList objectAtIndex:[pluginTable selectedRow]] objectForKey:@"availability"];
		BOOL pluginIsActive = [[[pluginsList objectAtIndex:[pluginTable selectedRow]] objectForKey:@"active"] boolValue];
		
		[PluginManager deletePluginWithName: pluginName
                               availability: availability
                                   isActive: pluginIsActive];
        
		[self refreshPluginList];
	}
}

- (IBAction)modifiyAvailability:(id)sender
{
	NSArray *pluginsList = [pluginsArrayController arrangedObjects];
	NSString *pluginName = [[pluginsList objectAtIndex:[pluginTable clickedRow]] objectForKey:@"name"];
	
	[PluginManager changeAvailabilityOfPluginWithName:pluginName to:[[sender selectedCell] title]];
	
	[self refreshPluginList]; // needed to restore the availability menu in case the user did provided a good admin password
}

- (IBAction)loadPlugins:(id)sender
{
	[PluginManager setMenus:filtersMenu :roisMenu :othersMenu :dbMenu];
}

- (void)windowWillClose:(NSNotification *)aNotification;
{
	[[self window] setAcceptsMouseMovedEvents: NO];
	
    @try
    {
        [self refreshPluginList];
    }
    @catch (NSException * e)
    {
        NSLog( @"windowwillClose exception pluginmanagercontroller: %@", e);
    }
}

- (IBAction)showWindow:(id)sender
{    
	if ([[self availableRemotePlugins] count] < 1)
	{
		[pluginsListPopUp removeAllItems];
		[pluginsListPopUp setEnabled:NO];
		[downloadButton setEnabled:NO];
		[statusTextField setHidden:NO];
		[statusTextField setStringValue:NSLocalizedString(@"No plugin server available.", nil)];
		//return;
	}
	else
	{
		[self generateAvailablePluginsMenu];
		[self setURLforPluginWithName:[[[self availableRemotePlugins] objectAtIndex:0] valueForKey:@"name"]];
		[self setDownloadUrlDict:[[[self availableRemotePlugins] objectAtIndex:0] valueForKey:@"download_url"]];
	}

	NSArray *viewers = [ViewerController getDisplayed2DViewers];
	for (ViewerController *viewer in viewers)
	{
		[[viewer window] close];
	}

	[super showWindow:sender];
	[self refreshPluginList];
    
    // If we need to remove a plugin with a custom pref pane
    for (NSWindow* window in [NSApp windows])
    {
        if ([window.windowController isKindOfClass:[PreferencesWindowController class]])
            [window close];
    }
}

- (void)refreshPluginList;
{
	NSIndexSet *selectedIndexes = [pluginTable selectedRowIndexes];
	
    [PluginManager setMenus:filtersMenu :roisMenu :othersMenu :dbMenu];
	
	[self willChangeValueForKey:@"plugins"];
	[plugins removeAllObjects];
	[plugins addObjectsFromArray:[PluginManager pluginsList]];
	[self didChangeValueForKey:@"plugins"];
	
	[pluginTable selectRowIndexes:selectedIndexes byExtendingSelection:NO];
}

#pragma mark - NSTabView Delegate methods

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if([tabViewItem isEqualTo:installedPluginsTabViewItem])
		[self refreshPluginList];
}

#pragma mark - web view

#pragma mark - pop up menu

NSInteger sortPluginArrayByName(id plugin1, id plugin2, void *context)
{
    NSString *name1 = [plugin1 objectForKey:@"name"];
    NSString *name2 = [plugin2 objectForKey:@"name"];
    
	return [name1 compare:name2 options: NSCaseInsensitiveSearch];
}

- (NSArray*) availableRemotePlugins;
{
	NSString *pluginsListURL = @"";
	NSArray *pluginsList = nil;
	
	if (CachedPluginsListDate == nil || [CachedPluginsListDate timeIntervalSinceNow] < -10*60)
	{
	}
	else if (CachedPluginsList)
	{
		return CachedPluginsList;
	}

	WaitRendering *splash = [[[WaitRendering alloc] init: NSLocalizedString( @"Check Plugins...", nil)] autorelease];
	[splash showWindow:self];

	for (int i=0; i<[pluginsListURLs count] && !pluginsList; i++)
	{
		pluginsListURL = [pluginsListURLs objectAtIndex:i];
		pluginsList = [NSArray arrayWithContentsOfURL:[NSURL URLWithString:pluginsListURL]];
	}
	
	[splash close];
	
    if (!pluginsList) {
        //NSLog(@"%s line:%d, no plugin list", __FUNCTION__, __LINE__);
        return nil;
    }
	
	NSArray *sortedPlugins = [pluginsList sortedArrayUsingFunction:sortPluginArrayByName context:NULL];
	
	[CachedPluginsListDate release];
	CachedPluginsListDate = [[NSDate date] retain];
	
	[CachedPluginsList release];
	CachedPluginsList = [sortedPlugins retain];
	
	return sortedPlugins;
}

- (void)generateAvailablePluginsMenu;
{
	[pluginsListPopUp removeAllItems];
	
	NSArray *availablePlugins = [self availableRemotePlugins];
	for (id loopItem in availablePlugins)
		[pluginsListPopUp addItemWithTitle:[loopItem objectForKey:@"name"]];
	
	[[pluginsListPopUp menu] addItem:[NSMenuItem separatorItem]];
	[pluginsListPopUp addItemWithTitle:NSLocalizedString(@"Your Plugin here!", nil)];
}

#pragma mark - web page

- (void)setURL:(NSString*)url;
{
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
}

- (void)setURLforPluginWithName:(NSString*)name;
{
	NSArray* availablePlugins = [self availableRemotePlugins];
	for (NSDictionary *plugin in availablePlugins)
	{
		if ([[plugin valueForKey:@"name"] isEqualToString:name])
		{
			[self setURL:[plugin valueForKey:@"url"]];
			[self setDownloadUrlDict:[plugin valueForKey:@"download_url"]];  // dictionary
			
			BOOL alreadyInstalled = NO;
			BOOL sameName = NO;
			BOOL sameVersion = NO;
			for (NSDictionary *installedPlugin in plugins)
			{
                NSString *path = [[plugin valueForKey:@"download_url"] valueForKey:@"path"];
                NSString *name = [[path lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				name = [name stringByDeletingPathExtension]; // removes the .zip extension
				name = [name stringByDeletingPathExtension]; // removes the .mieleplugin extension
				sameName = [name isEqualToString:[installedPlugin valueForKey:@"name"]];
				sameVersion = [[plugin valueForKey:@"version"] isEqualToString:[installedPlugin valueForKey:@"version"]];

				alreadyInstalled = alreadyInstalled || sameName || (sameName && sameVersion);
				
				if (alreadyInstalled)
                    break;
			} // for
			
			if (alreadyInstalled)
			{
				[statusTextField setHidden:NO];
				if (sameName && sameVersion)
					[statusTextField setStringValue:NSLocalizedString(@"Plugin already installed", nil)];
				else
					[statusTextField setStringValue:NSLocalizedString(@"Download the new version!", nil)];
			}
			else
			{
				[statusTextField setHidden:YES];
			}
			
			return;
		}
		else if([name isEqualToString:NSLocalizedString(@"Your Plugin here!", nil)])
		{
			[self loadSubmitPluginPage];
			return;
		}
	}  // for
}

- (IBAction)changeWebView:(id)sender
{
	[self setURLforPluginWithName:[sender title]];
}

#pragma mark - download

- (void)setDownloadUrlDict:(NSDictionary*)urlDic;
{
	if (downloadUrlDict)
        [downloadUrlDict release];

    downloadUrlDict = urlDic;
	[downloadUrlDict retain];
    
    NSString *path = [urlDic valueForKey:@"path"];
    if ([path length] == 0)
		[downloadButton setHidden:YES];
    else
		[downloadButton setHidden:NO];
}

- (void) fakeThread: (NSString*) downloadedFilePath
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    BOOL downloading = YES;    
    while (downloading)
    {
        @synchronized( downloadingPlugins)
        {
            if ([downloadingPlugins objectForKey: downloadedFilePath] == nil)
                downloading = NO;
            
            [NSThread sleepForTimeInterval: 1];
        }
    }
    
    [pool release];
}

- (IBAction)download:(id)sender
{
    NSString *path = [downloadUrlDict valueForKey:@"path"];
    NSString *lastComponent = [[path lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *downloadedFilePath = [NSString stringWithFormat:@"%@%@",
                                    NSTemporaryDirectory(),
                                    lastComponent];

#ifndef NDEBUG
    NSLog(@"%s %d, downloadedFilePath:<%@>", __FUNCTION__, __LINE__, downloadedFilePath);
#endif

    @synchronized( downloadingPlugins)
    {
        if ([downloadingPlugins objectForKey: downloadedFilePath]) {
            NSLog( @"---- Already downloading...");
        }
        else
        {
            NSURLComponents *urlComponents = [NSURLComponents new];
            [urlComponents setScheme:[downloadUrlDict valueForKey:@"scheme"]];
            [urlComponents setHost:[downloadUrlDict valueForKey:@"host"]];
            [urlComponents setPath:[downloadUrlDict valueForKey:@"path"]];
            
            NSURL *url = urlComponents.URL;
            if (!url) {
                NSLog(@"%s %d, null URL", __FUNCTION__, __LINE__);
                return;
            }

            NSURLDownload *download = [[[NSURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self] autorelease];

            [download setDestination: downloadedFilePath allowOverwrite:YES];
            
            [downloadingPlugins setObject: download forKey: downloadedFilePath];
            
            NSThread *t = [[[NSThread alloc] initWithTarget: self
                                                   selector: @selector(fakeThread:)
                                                     object: downloadedFilePath] autorelease];
            t.name = NSLocalizedString( @"Plugin download...", nil);
            t.status = [downloadUrlDict valueForKey:@"path"];
            [[ThreadsManager defaultManager] addThreadAndStart: t];
        }
    }
}

#pragma mark - NSURLDownloadDelegate

- (void)downloadDidBegin:(NSURLDownload *)download
{
	[statusTextField setHidden:NO];
	[statusTextField setStringValue:NSLocalizedString(@"Downloading...", nil)];
	[statusProgressIndicator setHidden:NO];
	[statusProgressIndicator startAnimation:self];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	[statusTextField setStringValue:NSLocalizedString(@"Plugin downloaded", nil)];
	[statusProgressIndicator setHidden:YES];
	[statusProgressIndicator stopAnimation:self];
    
    NSArray *paths = nil;
    @synchronized(downloadingPlugins)
    {
        paths = [downloadingPlugins allKeysForObject: download];
    }
    
    if (paths.count == 1)
    {
        [self installDownloadedPluginAtPath: [paths lastObject]];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:OsirixPluginDownloadInstallDidFinishNotification object:self userInfo:nil];
        
        @synchronized( downloadingPlugins)
        {
            [downloadingPlugins removeObjectForKey: [paths lastObject]];
        }
    }
    else
        NSLog( @"***** downloadDidFinish path for download?");
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	[statusTextField setHidden:NO];
	[statusTextField setStringValue:NSLocalizedString(@"Download failed", nil)];
     
    NSRunCriticalAlertPanel2(NSLocalizedString(@"Download failed", nil),
                             [error localizedDescription],
                            NSLocalizedString(@"OK", nil),
                            nil,
                            nil);
    
	[statusProgressIndicator setHidden:YES];
	[statusProgressIndicator stopAnimation:self];
    
    NSArray *paths = nil;
    @synchronized( downloadingPlugins)
    {
        paths = [downloadingPlugins allKeysForObject: download];
    }
    
    if (paths.count == 1)
    {
        @synchronized( downloadingPlugins)
        {
            [downloadingPlugins removeObjectForKey: [paths lastObject]];
        }
    }
    else
        NSLog( @"***** download didFailWithError path for download?");
}

#pragma mark - install

- (void)installDownloadedPluginAtPath:(NSString*)path;
{
	[statusProgressIndicator setHidden:NO];
	[statusProgressIndicator startAnimation:self];
	
	[statusTextField setStringValue:NSLocalizedString(@"Installing...", nil)];
	
	NSString *pluginPath = path;
	
	if ([self isZippedFileAtPath:path] &&
        [self unZipFileAtPath:path])
	{
		pluginPath = [path stringByDeletingPathExtension];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	}
    else
    {
        [statusTextField setStringValue:NSLocalizedString(@"Error: bad zip file", nil)];
        [statusProgressIndicator setHidden:YES];
        [statusProgressIndicator stopAnimation:self];
        return;
    }
	
	NSString *oldPath = [PluginManager deletePluginWithName: [pluginPath lastPathComponent]];
	
	// determine in which directory to install the plugin (default = user dir, or if the plugin was already installed: in the same dir)	
	NSString *installDirectoryPath;

	if (oldPath)
		installDirectoryPath = oldPath;
	else
		installDirectoryPath = [PluginManager userActivePluginsDirectoryPath];
	
    // Install the plugin
	[PluginManager movePluginFromPath:pluginPath toPath: installDirectoryPath];	
	
    // load the plugin
    [PluginManager loadPluginAtPath: [installDirectoryPath stringByAppendingPathComponent: [pluginPath lastPathComponent]]];
	
	[statusTextField setStringValue:NSLocalizedString( @"Plugin Installed", nil)];
	[statusProgressIndicator setHidden:YES];
	[statusProgressIndicator stopAnimation:self];

	[self refreshPluginList];
}

- (BOOL)isZippedFileAtPath:(NSString*)path;
{
    NSLog(@"%s path:<%@>", __PRETTY_FUNCTION__, path);
	return [[path pathExtension] isEqualTo:@"zip"];
}

- (BOOL)unZipFileAtPath:(NSString*)path;
{
    if (path.length == 0)
        return NO;
    
    @try
    {
        NSTask *aTask = [[NSTask alloc] init];
        NSMutableArray *args = [NSMutableArray array];

        [args addObject:@"-o"];
        [args addObject:path];
        [args addObject:@"-d"];
        [args addObject:[path stringByDeletingLastPathComponent]];
        [aTask setLaunchPath:@"/usr/bin/unzip"];
        [aTask setArguments:args];
        [aTask launch];
        while ([aTask isRunning])
            [NSThread sleepForTimeInterval: 0.1];
        
        //[aTask waitUntilExit];		// <- This is VERY DANGEROUS : the main runloop is continuing...
        [aTask release];
	}
    @catch (NSException *e)
    {
        NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
    }
        
	if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByDeletingPathExtension]])
		return YES;

    return NO;
}

#pragma mark - submit plugin

// Show the instructions for submitting a plugin
- (void)loadSubmitPluginPage;
{
#ifdef SUBMIT_PLUGIN_WITH_MAIL_APP
    if ([NSMailDelivery hasDeliveryClassBeenConfigured])
        [self setURL:PLUGIN_SUBMISSION_URL];
    else
#endif
    [self setURL:PLUGIN_SUBMISSION_NO_MAIL_APP_URL];
}

- (void)sendPluginSubmission:(NSString*)request;
{
	NSString *parameters = [[request componentsSeparatedByString:@"?"] objectAtIndex:1];
	NSArray *parametersArray = [parameters componentsSeparatedByString:@"&"];
		
	NSMutableString *emailMessage = [NSMutableString stringWithString:@""];
	
	for (id loopItem in parametersArray)
	{
		NSArray *param = [loopItem componentsSeparatedByString:@"="];
		[emailMessage appendFormat:@"%@: %@ \n", [param objectAtIndex:0], [[param objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}

#ifdef SUBMIT_PLUGIN_WITH_MAIL_APP
	NSString *emailAddress = URL_EMAIL;
	NSString *emailSubject = @"Miele-LXIV: New Plugin Submission"; // don't localize this. This is the subject of the email WE will receive.
	[NSMailDelivery deliverMessage:emailMessage subject:emailSubject to:emailAddress];
#else
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:" URL_EMAIL]];
#endif
}

#pragma mark - WebPolicyDelegate Protocol methods

- (void)webView:(WebView *)sender
decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
          frame:(WebFrame *)frame
decisionListener:(id<WebPolicyDecisionListener>)listener;
{
	if (![sender isEqualTo:webView])
        [listener use];

	if ([[actionInformation valueForKey:WebActionNavigationTypeKey] intValue]==WebNavigationTypeLinkClicked)
	{
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
	}
	else if([[actionInformation valueForKey:WebActionNavigationTypeKey] intValue]==WebNavigationTypeFormSubmitted)
	{
		[self sendPluginSubmission:[[request URL] absoluteString]];
	}
	else
	{
		[listener use];
	}
}

@end
