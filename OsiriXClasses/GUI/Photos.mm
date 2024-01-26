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
#import "Photos.h"
#import "NSAppleScript+N2.h"
//#import "CoreServices/AE/AppleEvents.h"

// if you want check point log info, define CHECK to the next line, uncommented:
#define CHECK NSLog(@"Applescript result code = %d", ok);

// // This converts an AEDesc into a corresponding NSValue.
//
//static id aedesc_to_id(AEDesc *desc)
//{
//	OSErr ok;
//
//	if (desc->descriptorType == typeChar)
//	{
//		NSMutableData *outBytes;
//		NSString *txt;
//
//		outBytes = [[NSMutableData alloc] initWithLength:AEGetDescDataSize(desc)];
//		ok = AEGetDescData(desc, [outBytes mutableBytes], [outBytes length]);
//		CHECK;
//
//		txt = [[NSString alloc] initWithData:outBytes encoding: NSUTF8StringEncoding];
//		[outBytes release];
//		[txt autorelease];
//
//		return txt;
//	}
//
//	if (desc->descriptorType == typeSInt16)
//	{
//		SInt16 buf;
//		
//		AEGetDescData(desc, &buf, sizeof(buf));
//		
//		return [NSNumber numberWithShort:buf];
//	}
//
//	return [NSString stringWithFormat:@"[unconverted AEDesc, type=\"%c%c%c%c\"]", ((char *)&(desc->descriptorType))[0], ((char *)&(desc->descriptorType))[1], ((char *)&(desc->descriptorType))[2], ((char *)&(desc->descriptorType))[3]];
//}

@implementation Photos

- (NSString *) scriptBody:(NSArray*) files
{
	NSString *albumName = [[NSUserDefaults standardUserDefaults] stringForKey: @"ALBUMNAME"];
	
    //NSLog(@"%s:%i albumName:<%@>", __FILE__, __LINE__, albumName);
    
	NSMutableString *s = [NSMutableString stringWithCapacity:1000];

    [s appendString:@"tell application \"Photos\"\n"];

    [s appendString:[NSString stringWithFormat:@"if not (exists album \"%@\") then\n", albumName]];
    [s appendString:[NSString stringWithFormat:@"make new album named \"%@\"\n", albumName]];
    [s appendString:@"end if\n"];
    [s appendString:[NSString stringWithFormat:@"set this_album to album \"%@\"\n", albumName]];
    
    for (id loopItem in files)
        [s appendString:[NSString stringWithFormat:@"import (POSIX file \"%@\" as alias) into this_album skip check duplicates yes\n", loopItem]];

    [s appendString:@"activate\n"];
	[s appendString:@"end tell\n"];
	
    //NSLog(@"%s:%i %@", __FILE__, __LINE__, s);

    return s;
}

- (BOOL)importIniPhoto: (NSArray*) files
{
	[self runScript:[self scriptBody:files]];
	return YES;
}

// initialize it in your init method:

- (id)init
{
	self = [super init];
	if (self)
	{
	}

    return self;
}

// Issue #g56
- (bool) automationConsent: (NSString *)bundleID
{
    bool consentResult = true;

    NSAppleEventDescriptor *targetAppEventDescriptor = [NSAppleEventDescriptor descriptorWithBundleIdentifier:bundleID];
    
    if (@available(macOS 10.14, *))
    {
        OSStatus appleScriptPermission
            = AEDeterminePermissionToAutomateTarget(targetAppEventDescriptor.aeDesc, // AEAddressDesc
                                                    typeWildCard, // AEEventClass
                                                    typeWildCard, // AEEventID
                                                    true); // askUserIfNeeded

        switch (appleScriptPermission) {
            case procNotFound:
            {
                NSArray *listItems = [bundleID componentsSeparatedByString:@"."];
                NSString *targetApp = [listItems lastObject];
                NSAlert *alert = [NSAlert new];
                [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%@ is not running", "AppleScript permission"), targetApp]];
                [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Please start %@ and retry", "AppleScript permission"), targetApp]];
                [alert addButtonWithTitle:NSLocalizedString(@"OK",nil)];
                [alert setAlertStyle:NSAlertStyleInformational];
                [alert runModal];
            }
                consentResult = false;
                break;

            case errAEEventNotPermitted:
                NSLog(@"The current application is not permitted to send events to %@", bundleID);
                // the user does not consent
                consentResult = false;
                break;
                
            case errAEEventWouldRequireUserConsent:
                // If askUserIfNeeded is false, and this application is not yet permitted to send AppleEvents to the target, then errAEEventWouldRequireUserConsent will be returned
                NSLog(@"Automation consent not yet granted for %@, would require user consent.", bundleID);
                consentResult = false;
                break;

            case noErr:
                NSLog(@"Automation permitted for %@.", bundleID);
                // the current application is permitted to send the given AppleEvent to the target
                break;

            default:
                NSLog(@"%s switch statement fell through: %@ %d", __PRETTY_FUNCTION__, bundleID, appleScriptPermission);
                consentResult = false;
                break;
        }
    }
    else {
        // Fallback on earlier versions
    }

    return consentResult;
}

// do the grunge work -
// the sweetly wrapped method is all we need to know:

- (void)runScript:(NSString *)txt
{
    // Issue #g56
    if (![self automationConsent:@"com.apple.Photos"])
        return;

    NSAppleScript* as = [[[NSAppleScript alloc] initWithSource:txt] autorelease];
    NSDictionary* errs = nil;
    [as runWithArguments:nil error:&errs];
    if ([errs count])
        NSLog(@"Error: AppleScript execution failed: %@", errs);
}

@end
