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

// This will be added to the main index page of the Doxygen documentation
/** \mainpage Miele-LXIV index page
*  <img src= "../../../../Assets.xcassets/AppIcon.appiconset/icon_32x32.png">
* \section Intro Miele-LXIV DICOM workstation
*  Miele-LXIV is a free open source DICOM workstation with full 64 bit support.
*
*  We extend our thanks to others in the open source community.
*
*  VTK, ITK, and DCMTK open source projects are extensively used in Miele-LXIV.
*
*  The Miele-LXIV team.
*/

#import <AppKit/AppKit.h>
#import "UserNotifications/UserNotifications.h"
#import "XMLRPCMethods.h"

#import "options.h"

//@class ThreadPoolServer;
//@class ThreadPerConnectionServer;

//#import "IChatTheatreDelegate.h"

@class PreferenceController;
@class BrowserController;
@class SplashScreen;
@class DCMNetServiceDelegate;
@class WebPortal;

enum
{
	compression_sameAsDefault = 0,
	compression_none = 1,
	compression_JPEG = 2,
	compression_JPEG2000 = 3,
    compression_JPEGLS = 4
};

typedef NS_ENUM(NSUInteger, MultipleScreenType) {
    MULTIPLE_SCREEN_TYPE_MAIN_ONLY = 0, // use main screen only
    MULTIPLE_SCREEN_TYPE_2ND_ONLY = 1,  // use second screen only
    MULTIPLE_SCREEN_TYPE_ALL = 2        // use all screens
};

#pragma mark -

@class PluginFilter;

#ifdef __cplusplus
extern "C"
{
#endif
	NSRect screenFrame();
	NSString * documentsDirectoryFor( int mode, NSString *url) __deprecated;
	NSString * documentsDirectory() __deprecated;
#ifdef __cplusplus
}
#endif

/** \brief  NSApplication delegate
*
*  NSApplication delegate 
*  Primarily manages the user defaults and server
*  Also controls some general main items
*
*
*/

@class AppController, ToolbarPanelController, ThumbnailsListPanel, BonjourPublisher;

extern AppController* MieleLXIV;

#pragma mark -

@interface AppController : NSObject	<NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, NSSoundDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate>
{
	IBOutlet BrowserController		*browserController;

    IBOutlet NSMenu					*filtersMenu;
	IBOutlet NSMenu					*roisMenu;
	IBOutlet NSMenu					*othersMenu;
	IBOutlet NSMenu					*dbMenu;
	IBOutlet NSWindow				*dbWindow;
	IBOutlet NSMenu					*windowsTilingMenuRows, *windowsTilingMenuColumns;
    IBOutlet NSMenu                 *recentStudiesMenu;
	
	NSDictionary					*previousDefaults;
	
	BOOL							showRestartNeeded;
		
    SplashScreen					*splashController;
	
    volatile BOOL					quitting;
	BOOL							verboseUpdateCheck;
	NSNetService					*BonjourDICOMService;
	
	NSTimer							*updateTimer;
	XMLRPCInterface					*XMLRPCServer;
	
	BOOL							checkAllWindowsAreVisibleIsOff, isSessionInactive;
	
	int								lastColumns, lastRows, lastCount;
    
    BonjourPublisher* _bonjourPublisher;
}

@property BOOL checkAllWindowsAreVisibleIsOff, isSessionInactive;
@property (readonly) NSMenu *filtersMenu, *recentStudiesMenu, *windowsTilingMenuRows, *windowsTilingMenuColumns;
@property(readonly) NSNetService* dicomBonjourPublisher;
@property (readonly) XMLRPCInterface *XMLRPCServer;
@property(readonly) BonjourPublisher* bonjourPublisher;

+ (BOOL) isFDACleared;
+ (BOOL) willExecutePlugin;
+ (BOOL) willExecutePlugin:(id) filter;

+ (BOOL) meetMacOsVersionMinRequired;     // 10.13
+ (BOOL) validatedWithThisMacOS;

+(NSString*)UID;

#pragma mark - initialization of the main event loop singleton

+ (void) createNoIndexDirectoryIfNecessary:(NSString*) path __deprecated;
#ifdef WITH_IMPORTANT_NOTICE
+ (void) displayImportantNotice:(id) sender;
#endif
+ (AppController*) sharedAppController; /**< Return the shared AppController instance */
+ (void) resizeWindowWithAnimation:(NSWindow*) window newSize: (NSRect) newWindowFrame;
+ (void) pause __deprecated;
+ (ThumbnailsListPanel*)thumbnailsListPanelForScreen:(NSScreen*)screen;
+ (NSString*)printStackTrace:(NSException*)e __deprecated; // use -[NSException printStackTrace] from NSException+N2
+ (BOOL) isKDUEngineAvailable;

#pragma mark - HTML Templates
+ (void)checkForHTMLTemplates __deprecated;

#pragma mark - Server management
- (void) terminate:(id) sender; /**< Terminate listener (Q/R SCP) */
- (void) restartSTORESCP; /**< Restart listener (Q/R SCP) */
- (void) startSTORESCP:(id) sender; /**< Start listener (Q/R SCP) */
- (void) startSTORESCPTLS:(id) sender; /**< Start TLS listener (Q/R SCP) */
- (void) installPlugins: (NSArray*) pluginsArray;
- (BOOL) isStoreSCPRunning;

#pragma mark - static menu items

//===============OSIRIX========================
- (IBAction) about:(id)sender; /**< Display the about window */
- (IBAction) showPreferencePanel:(id)sender; /**< Show Preferences window */
#ifndef MIELE_LIGHT
- (IBAction) checkForUpdates:(id) sender;  /**< Check for update */
- (IBAction) autoQueryRefresh:(id)sender;
#endif

//===============WINDOW========================
- (IBAction) setFixedTilingRows: (id) sender;
- (IBAction) setFixedTilingColumns: (id) sender;
- (void) initTilingWindows;
- (IBAction) tileWindows:(id)sender;  /**< Tile open window */
- (IBAction) tile3DWindows:(id)sender; /**< Tile 3D open window */
- (void) tileWindows:(id)sender windows: (NSMutableArray*) viewersList display2DViewerToolbar: (BOOL) display2DViewerToolbar displayThumbnailsList: (BOOL) displayThumbnailsList;
- (void) scaleToFit:(id)sender;    /**< Scale opened windows */
- (IBAction) closeAllViewers: (id) sender;  /**< Close All Viewers */
- (void) checkAllWindowsAreVisible:(id) sender;
- (void) checkAllWindowsAreVisible:(id) sender makeKey: (BOOL) makeKey;
//- (IBAction)toggleActivityWindow:(id)sender;

//===============HELP==========================
- (IBAction) sendEmail: (id) sender;   /**< Send email to lead developer */

// "Open" means open in web browser
- (IBAction) openMieleLXIVWebPage: (id) sender;
- (IBAction) openMieleLXIVDonation: (id) sender;
- (IBAction) openMieleLXIVSourceCode: (id) sender;
- (IBAction) openMieleLXIVDiscussion: (id) sender;

//- (IBAction) osirix64bit: (id) sender;
- (IBAction) userManual: (id) sender;
- (IBAction) conformanceStatement: (id) sender;
//---------------------------------------------
- (IBAction) help: (id) sender;  /**< Open help window */
//=============================================

- (IBAction) killAllStoreSCU:(id) sender;

- (id) splashScreen;

#pragma mark - window routines

- (IBAction) updateViews:(id) sender;  /**< Update Viewers */
- (NSScreen *)dbScreen;  /**< Return monitor with DB */
- (NSArray *)viewerScreens; /**< Return array of monitors for displaying viewers */

 /** 
 * Find the WindowController with the named nib and using the pixList
 * This is commonly used to find the 3D Viewer associated with a ViewerController.
 * Conversely this could be used to find the ViewerController that created a 3D Viewer
 * Each 3D Viewer has its own distinctly named nib as does the ViewerController.
 * The pixList is the Array of DCMPix that the viewer uses.  It should uniquely identify related viewers
*/
- (id) FindViewer:(NSString*) nibName :(NSArray*) pixList;

- (NSArray*) FindRelatedViewers:(NSArray*) pixList; /**< Return an array of all WindowControllers using the pixList */
- (IBAction) cancelModal: (id) sender;
- (IBAction) okModal: (id) sender;
- (NSString*) privateIP;
- (void) killDICOMListenerWait:(BOOL) w;
- (void) runPreferencesUpdateCheck:(NSTimer*) timer;
+ (void) checkForPreferencesUpdate: (BOOL) b;
+ (BOOL) useToolBarPanel;
+ (void) setUseToolBarPanel: (BOOL) b;
+ (NSRect) usefulRectForScreen: (NSScreen*) screen;

- (void) addStudyToRecentStudiesMenu: (NSManagedObjectID*) studyID;
- (void) loadRecentStudy: (id) sender;
- (void) buildRecentStudiesMenu;

- (NSMenu*) viewerMenu;
- (NSMenu*) fileMenu;
- (NSMenu*) exportMenu;
- (NSMenu*)imageTilingMenu;
- (NSMenu*) orientationMenu;
- (NSMenu*) opacityMenu;
- (NSMenu*) wlwwMenu;
- (NSMenu*) convMenu;
- (NSMenu*) clutMenu;
- (NSMenu*) workspaceMenu;

#pragma mark - growl
- (void) growlTitle:(NSString*) title description:(NSString*) description name:(NSString*) name;

//#pragma mark - display setters and getters
//- (IBAction) saveLayout: (id)sender;

#pragma mark - 12 Bit Display support.
+ (BOOL)canDisplay12Bit;
+ (void)setCanDisplay12Bit:(BOOL)boo;
+ (void)setLUT12toRGB:(unsigned char*)lut;
+ (unsigned char*)LUT12toRGB;
+ (void)set12BitInvocation:(NSInvocation*)invocation;
+ (NSInvocation*)fill12BitBufferInvocation;

#pragma mark -
-(WebPortal*)defaultWebPortal;

#ifndef MIELE_LIGHT
-(NSString*)weasisBasePath;
#endif

-(void)setReceivingIcon;
-(void)unsetReceivingIcon;
-(void)setBadgeLabel:(NSString*)label;

- (void)playGrabSound;

@end

