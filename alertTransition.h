//
//  alertTransition.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 22 Oct 2024
//  Copyright (c) 2024 Miele_LXIV Team. All rights reserved.
//  License GPLv3.0 -- see License File
//

// PURPOSE: help transitioning from deprecated API

#import <AppKit/AppKit.h>

#define NSAlertDefaultReturn2       NSAlertFirstButtonReturn
#define NSAlertAlternateReturn2     NSAlertSecondButtonReturn
#define NSAlertOtherReturn2         NSAlertThirdButtonReturn

static inline NSInteger LXIVRunAlertPanel(NSString *title,
                                          NSString *message,
                                          NSString *defaultButton,
                                          NSString *alternateButton,
                                          NSString *otherButton,
                                          NSAlertStyle style)
{
    NSAlert *alert = [NSAlert new];
    [alert setAlertStyle:style];
    [alert setMessageText:title ?: @""];
    [alert setInformativeText:message ?: @""];
	
    [alert addButtonWithTitle:defaultButton ?: NSLocalizedString(@"OK", nil)];

    if (alternateButton)
        [alert addButtonWithTitle:alternateButton];
		
    if (otherButton)
        [alert addButtonWithTitle:otherButton];

    NSInteger response = [alert runModal];
    [alert release];
    return response;
}
static inline NSInteger NSRunAlertPanel2(NSString *title,
                           NSString *message,
                           NSString *defaultButton,
                           NSString *alternateButton,
                           NSString *otherButton)
{
    return LXIVRunAlertPanel(title, message, defaultButton, alternateButton, otherButton, NSAlertStyleWarning);
}

static inline NSInteger NSRunInformationalAlertPanel2(NSString *title,
                           NSString *message,
                           NSString *defaultButton,
                           NSString *alternateButton,
                           NSString *otherButton)
{
    return LXIVRunAlertPanel(title, message, defaultButton, alternateButton, otherButton, NSAlertStyleInformational);
}

static inline NSInteger NSRunCriticalAlertPanel2(NSString *title,
                                                 NSString *message,
                                                 NSString *defaultButton,
                                                 NSString *alternateButton,
                                                 NSString *otherButton)
{
    return LXIVRunAlertPanel(title, message, defaultButton, alternateButton, otherButton, NSAlertStyleCritical);
}