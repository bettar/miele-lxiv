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

#import "PathForImage.h"
#import "BrowserController.h"
#import "AppDefaults.h"

const char *pathToJPEG(const char *sopInstanceUID)
{
	NSString *path = [[[BrowserController currentBrowser] fixedDocumentsDirectory] stringByAppendingPathComponent:REPORTS_PATH];
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	BOOL isDir;
	//CHECK FOR REPORTS FOLDER
	if (!([defaultManager fileExistsAtPath:path isDirectory:&isDir] && isDir))
		[defaultManager createDirectoryAtPath: path
                  withIntermediateDirectories: YES
                                   attributes: nil
                                        error: nil];

    //CHECK AND CREATE JPEGS SUBFOLDER
	path = [path stringByAppendingPathComponent:@"JPEGS"];
	if (!([defaultManager fileExistsAtPath:path isDirectory:&isDir] && isDir))
		[defaultManager createDirectoryAtPath: path
                  withIntermediateDirectories: YES
                                   attributes: nil
                                        error: nil];

    //CREATE JPEG FOR HTML VIEWING
	NSString *imageUID = [NSString stringWithFormat:@"%s", sopInstanceUID];
	path = [path stringByAppendingPathComponent:imageUID];
	NSURL *url = [NSURL fileURLWithPath:path];
	return [[url absoluteString] UTF8String];
}
