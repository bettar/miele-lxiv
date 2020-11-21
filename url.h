//
//  url.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 22 Nov 2014.
//  Copyright (c) 2014-2018 Miele_LXIV Team. All rights reserved.
//  License GPLv3.0 -- see License File
//

#ifndef URL_H_INCLUDED
#define URL_H_INCLUDED

#define URL_MIELE_SOURCES           @"https://github.com/bettar/miele-lxiv"
#define URL_MIELE_HOME_PAGE         @"https://dicom.3utilities.com"
#define URL_MIELE_WEB_PAGE          @"http://bettar.github.io/miele-lxiv"
#define URL_MIELE_MAC_APP_STORE     @"https://apps.apple.com/us/app/miele-lxiv/id988332475"

#define URL_MIELE_WEB_RESOURCES     @"https://raw.githubusercontent.com/bettar/miele-lxiv"
#define URL_VENDOR                  @"http://bettar.no-ip.org/lxiv"
#define URL_EMAIL                   @"miele-lxiv@gmx.com"

#define URL_VENDOR_NOTICE           URL_VENDOR@"/products.html#OsiriXMD"
#define URL_VENDOR_USER_MANUAL      URL_VENDOR@"/products.html#OsiriXUserManual"

#define URL_OSIRIX_BANNER           URL_MIELE_WEB_PAGE@"/OsiriXBanner.png"
#define URL_CLICK_BANNER            URL_MIELE_WEB_PAGE@"/Banner.html"

#define URL_OSIRIX_DOC_SECURITY     URL_MIELE_WEB_PAGE@"/Documentation/Guides/Security/index.html"
#define URL_OSIRIX_LEARNING         URL_MIELE_WEB_PAGE@"/Learning.html"
//#define URL_OSIRIX_DISCUSSION     @"http://groups.yahoo.com/group/osirix/"
#define URL_MIELE_DISCUSSION        @"https://github.com/bettar/miele-lxiv/wiki"
#define URL_OSIRIX_UPDATE           URL_VENDOR@"/download.html"
#define URL_OSIRIX_UPDATE_CRASH     URL_VENDOR@"/download.html"
#define URL_MIELE_VERSION           URL_MIELE_WEB_RESOURCES@"/lxiv/version.xml"
#define KEY_VERSION_CHECK           "Miele-LXIV"

#define URL_OSIRIX_PLUGINS          URL_MIELE_WEB_PAGE@"/Plugins.html"

// /////////////////////////////////////////////////////////////////////////////
// We want our own Defaults plist saved in ~/Library/Preferences/
// Make sure it matches "Bundle Identifier" in Deployment-Info.plist

// Company ID
#define BUNDLE_IDENTIFIER_PREFIX    "com.bettarini"

// CFBundleIdentifier = Company ID + CFBundleName
#define BUNDLE_IDENTIFIER           "com.bettarini.miele-lxiv"

// /////////////////////////////////////////////////////////////////////////////
// This is the address of the plist containing the list of the available plugins.
// the alternative link will be used if the first one doesn't reply...

#define PLUGINS_MIELE                       URL_MIELE_WEB_RESOURCES@"/gh-pages/plugins/miele-lxiv.plist"
#define PLUGINS_MIELE_TEST                  URL_MIELE_WEB_RESOURCES@"/gh-pages/plugins/miele-lxiv-test.plist"
#define PLUGINS_MIELE_MIRROR1               PLUGINS_MIELE

// Obsolete:
//#define PLUGINS_OSIRIX                      @"http://www.osirix-viewer.com/osirix_plugins/plugins.plist"
//#define PLUGINS_OSIRIX_MIRROR1              @"http://www.osirixviewer.com/osirix_plugins/plugins.plist"

#define URL_PLUGIN_LIST                     PLUGINS_MIELE
#define URL_PLUGIN_LIST_MIRROR1             PLUGINS_MIELE_MIRROR1

// /////////////////////////////////////////////////////////////////////////////
// Plugin submission method

//#define SUBMIT_PLUGIN_WITH_MAIL_APP

// HTML form with Submit button for HTTP GET
#define PLUGIN_SUBMISSION_URL               URL_MIELE_WEB_PAGE@"/submit_plugin/index.html"


#define PLUGIN_SUBMISSION_NO_MAIL_APP_URL   URL_MIELE_WEB_PAGE@"/submit_plugin/index_no_mail_app.html"

// /////////////////////////////////////////////////////////////////////////////
#define SYNC_DB_URL             @"http://list.dicom.dcm/DB.plist"  // was OsiriXDB.plist"
#define SYNC_DICOM_NODES_URL    @"http://list.dicom.dcm/DICOMNodes.plist"
#define HELP_SQL_SYNTAX_URL         @"https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html#//apple_ref/doc/uid/TP40001795-215868"

// /////////////////////////////////////////////////////////////////////////////
// Our identity

#define OUR_IMPLEMENTATION_NAME @"MIELE"
#define OUR_AET                 "Miele-LXIV"
#define OUR_MANUFACTURER_NAME   "Miele-LXIV"

#define OUR_HTTP_ACCOUNT        @"OsiriX"
#define OUR_HTTP_SERVICE        @"OsiriX HTTP Server"
#define OUR_HTTP_SERVER_LABEL   @"com.osirixviewer.osirixwebserver"
#define OUR_CERTIFICATE_EMAIL   @"miele-lxiv@gmx.com" // @"osirix@osirix-viewer.com"
#define CRASH_EMAIL             @"miele-lxiv@gmx.com" // @"crash@osirix-viewer.com"

#define OUR_DATA_LOCATION       @"Miele-LXIV Data"  // TODO: use CFBundleName
#define OUR_IMAGE_JPG           @"Miele-LXIV.jpg"   // for exported images

#endif
