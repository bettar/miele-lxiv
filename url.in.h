//
//  url.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 22 Nov 2014.
//  Copyright (c) 2014-2022 Miele_LXIV Team. All rights reserved.
//  License GPLv3.0 -- see License File
//

#ifndef URL_H_INCLUDED
#define URL_H_INCLUDED

#define URL_MIELE_SOURCES           @"https://your.sourcecode.com"
#define URL_MIELE_HOME_PAGE         @"https://your.homepage.com"
#define URL_MIELE_DONATION          @"https://your.donations.com"
#define URL_MIELE_WEB_PAGE          @"http://your.webpage.com"
#define URL_MIELE_MAC_APP_STORE     @"https://apps.apple.com/us/app/you/your-id"

#define URL_MIELE_WEB_RESOURCES     @"https://raw.githubusercontent.com/your-account/miele-lxiv"
#define URL_VENDOR                  @"https://your-url/lxiv"
#define URL_EMAIL                   @"your-email@your-provider.com"

#define URL_VENDOR_NOTICE           URL_VENDOR@"/products.html#Notice"
#define URL_VENDOR_USER_MANUAL      URL_VENDOR@"/products.html#UserManual"

#define URL_OSIRIX_BANNER           URL_MIELE_WEB_PAGE@"/yourBanner.png"
#define URL_CLICK_BANNER            URL_MIELE_WEB_PAGE@"/Banner.html"

#define URL_OSIRIX_DOC_SECURITY     URL_MIELE_WEB_PAGE@"/Documentation/Guides/Security/index.html"
#define URL_OSIRIX_LEARNING         URL_MIELE_WEB_PAGE@"/Learning.html"
#define URL_MIELE_DISCUSSION        @"https://github.com/your-account/miele-lxiv/wiki"
#define URL_OSIRIX_UPDATE           URL_VENDOR@"/download.html"
#define URL_OSIRIX_UPDATE_CRASH     URL_VENDOR@"/download.html"
#define URL_MIELE_VERSION           URL_MIELE_WEB_RESOURCES@"/lxiv/version.xml"
#define KEY_VERSION_CHECK           "Miele-LXIV"

#define URL_OSIRIX_PLUGINS          URL_MIELE_WEB_PAGE@"/Plugins.html"

// /////////////////////////////////////////////////////////////////////////////
// We want our own Defaults plist saved in ~/Library/Preferences/
// Make sure it matches "Bundle Identifier" in Deployment-Info.plist

// Company ID
#define BUNDLE_IDENTIFIER_PREFIX    "com.yourprefix"

// CFBundleIdentifier = Company ID + CFBundleName
#define BUNDLE_IDENTIFIER           "com.yourname.miele-lxiv"

// /////////////////////////////////////////////////////////////////////////////
// This is the address of the plist containing the list of the available plugins.
// the alternative link will be used if the first one doesn't reply...

#define PLUGINS_MIELE                   URL_MIELE_WEB_RESOURCES@"/gh-pages/plugins/miele-lxiv.plist"
#define PLUGINS_MIELE_TEST              URL_MIELE_WEB_RESOURCES@"/gh-pages/plugins/miele-lxiv-test.plist"
#define PLUGINS_MIELE_MIRROR1           PLUGINS_MIELE

#define URL_PLUGIN_LIST                 PLUGINS_MIELE
#define URL_PLUGIN_LIST_MIRROR1         PLUGINS_MIELE_MIRROR1

// /////////////////////////////////////////////////////////////////////////////
// Plugin submission

//#define SUBMIT_PLUGIN_WITH_MAIL_APP

// HTML form with Submit button for HTTP GET
#define PLUGIN_SUBMISSION_URL               URL_MIELE_WEB_PAGE@"/submit_plugin/index.html"
#define PLUGIN_SUBMISSION_NO_MAIL_APP_URL   URL_MIELE_WEB_PAGE@"/submit_plugin/index_no_mail_app.html"

// /////////////////////////////////////////////////////////////////////////////
#define SYNC_DB_URL             @"http://list.dicom.dcm/DB.plist"
#define SYNC_DICOM_NODES_URL    @"http://list.dicom.dcm/DICOMNodes.plist"
#define HELP_SQL_SYNTAX_URL     @"https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html#//apple_ref/doc/uid/TP40001795-215868"

// /////////////////////////////////////////////////////////////////////////////
// Our identity

#define OUR_IMPLEMENTATION_NAME @"MIELE"
#define OUR_AET                 "Miele-LXIV"
#define OUR_MANUFACTURER_NAME   "Miele-LXIV"

#define OUR_HTTP_ACCOUNT        @"Miele-LXIV"
#define OUR_HTTP_SERVICE        @"Miele-LXIV HTTP Server"
#define OUR_HTTP_PASSWORD       @"Miele-LXIV password"

#define OUR_HTTP_SERVER_LABEL   @"com.mielelxivviewer.mielelxivwebserver"

#define OUR_CERTIFICATE_EMAIL   @"your-cert-email@your-provider.com"
#define CRASH_EMAIL             @"your-crash-email@your-provider.com"

#define OUR_DATA_LOCATION       @"Miele-LXIV Data"  // TODO: use CFBundleName
#define OUR_IMAGE_JPG           @"Miele-LXIV.jpg"   // for exported images

#endif
