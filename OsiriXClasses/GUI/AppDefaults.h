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
#import "options.h"

// /////////////////////////////////////////////////////////////////////////////
// _a_ array
// _b_ boolean
// _i_ integer
// _s_ string
#define OpenViewer_b_KEY            @"OPENVIEWER"                   // It also has I.B. binding
#define DbLocation_i_KEY            @"DATABASELOCATION"
#define DbLocationUrl_s_KEY         @"DATABASELOCATIONURL"
#define DbVersion_s_KEY             @"DATABASEVERSION"              // contents of file DB_VERSION_FILE
#define DefaultDbLocation_i_KEY     @"DEFAULT_DATABASELOCATION"     // used by matrix of radio buttons, 0=documents dir, 1=user selected
#define DefaultDbLocationUrl_s_KEY  @"DEFAULT_DATABASELOCATIONURL"
#define MieleServers_a_KEY          @"OSIRIXSERVERS"    // Array of dictionaries: Activated, Address, AETitle, Port, TransferSyntax, Description
#define Servers_a_KEY               @"SERVERS"          // Array of dictionaries: Activated, Address, AETitle, Port, Send

#define localDatabasePaths_a_KEY    @"localDatabasePaths"           // It also has I.B. binding. Array of dictionaries: "Path" "Description"

#define DEFAULT_FolderSizeForDB     10000
#define FolderSizeForDB_i_KEY       @"DefaultFolderSizeForDB"

// /////////////////////////////////////////////////////////////////////////////
// Security scoped bookmarks
#define DbLocationUrl_bk_KEY        @"DB location bookmark"
#define LocalDbPath_bk_KEY          @"Local DB path bookmark"

// /////////////////////////////////////////////////////////////////////////////
// Sub-directories of OUR_DATA_LOCATION
#define STATE_3D_DB_PATH        @"3DSTATE"
#define DATABASE_PATH           @"DATABASE.noindex"
#define DECOMPRESSION_PATH      @"DECOMPRESSION.noindex"
#define DUMP_PATH               @"DUMP"
#define ERR_PATH                @"NOT READABLE"
#define HTML_EXTRA_PATH         @"html-extra"
#define HTML_TEMPLATES_PATH     @"HTML_TEMPLATES"
#define INCOMING_PATH           @"INCOMING.noindex"
#define LOADING_PATH            @"Loading"
#define PAGES_PATH              @"PAGES"
#define PHOTOS_PATH             @"PHOTOS"
#define REPORTS_PATH            @"REPORTS"
#define ROIS_PATH               @"ROIs"
#define TO_BE_INDEXED_PATH      @"TOBEINDEXED.noindex"
#define TEMP_PATH               @"TEMP.noindex"
#define TEMPLATES_PATH          @"TEMPLATES"

// Files in OUR_DATA_LOCATION
#define DB_SQL_FILE             @"Database.sql"
#define DB3_SQL_FILE            @"Database3.sql"
#define DB3_SQL_J_FILE          @"Database3.sql-journal" // see https://sqlite.org/tempfiles.html
#define DB_OLD_SQL_FILE         @"Database-Old-PreviousVersion.sql"
#define DB_VERSION_FILE         @"DB_VERSION"
#define ALBUM_SORT_PLIST_FILE   @"AlbumSortDescriptors.plist"

// File alias
#define DB_FOLDER_FILE          @"DBFOLDER_LOCATION"

// /////////////////////////////////////////////////////////////////////////////
// WARNING: If you add or modify this list, check ViewerController.m, DCMView.h and HotKey Pref Pane
enum HotKeyActions {DefaultWWWLHotKeyAction = 0, FullDynamicWWWLHotKeyAction, 
	Preset1WWWLHotKeyAction, Preset2WWWLHotKeyAction, Preset3WWWLHotKeyAction, 
	Preset4WWWLHotKeyAction, Preset5WWWLHotKeyAction, Preset6WWWLHotKeyAction, 
	Preset7WWWLHotKeyAction, Preset8WWWLHotKeyAction, Preset9WWWLHotKeyAction,
	FlipVerticalHotKeyAction, FlipHorizontalHotKeyAction,
	WWWLToolHotKeyAction, MoveHotKeyAction, ZoomHotKeyAction, RotateHotKeyAction,
	ScrollHotKeyAction, LengthHotKeyAction, AngleHotKeyAction, RectangleHotKeyAction,
	OvalHotKeyAction, TextHotKeyAction, ArrowHotKeyAction, OpenPolygonHotKeyAction,
	ClosedPolygonHotKeyAction, PencilHotKeyAction, ThreeDPointHotKeyAction, PlainToolHotKeyAction,
	BoneRemovalHotKeyAction, Rotate3DHotKeyAction, Camera3DotKeyAction, scissors3DHotKeyAction, RepulsorHotKeyAction, SelectorHotKeyAction, EmptyHotKeyAction, UnreadHotKeyAction, ReviewedHotKeyAction, DictatedHotKeyAction, ValidatedHotKeyAction, OrthoMPRCrossHotKeyAction, Preset1OpacityHotKeyAction, Preset2OpacityHotKeyAction, Preset3OpacityHotKeyAction, Preset4OpacityHotKeyAction, Preset5OpacityHotKeyAction, Preset6OpacityHotKeyAction, Preset7OpacityHotKeyAction, Preset8OpacityHotKeyAction, Preset9OpacityHotKeyAction, FullScreenAction, Sync3DAction, SetKeyImageAction};


/** \brief Sets up user defaults */
@interface AppDefaults : NSObject {

}

+ (NSMutableDictionary*) getDefaults;
//+ (NSString*) hostName;
+ (NSHost*) currentHost;

+ (mach_vm_size_t) GPUModelVRAMInfo;
#if 0 // obsolete
+ (unsigned long) vramSizeMB;
#endif

+ (NSURL *) resolveStoredBookmark:(NSString *) key;
+ (void) createAndStoreBookmark:(NSURL *) url
                       underKey:(NSString *) key;
// TODO: removeStoredBookmark:(NSString *) key;
@end
