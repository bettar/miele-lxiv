//
//  alertTransition.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 22 Oct 2024
//  Copyright (c) 2024 Miele_LXIV Team. All rights reserved.
//  License GPLv3.0 -- see License File
//

// PURPOSE: help transitioning from deprecated API

#define NSAlertDefaultReturn2       NSAlertFirstButtonReturn
#define NSAlertAlternateReturn2     NSAlertSecondButtonReturn
#define NSAlertOtherReturn2         NSAlertThirdButtonReturn

extern NSInteger NSRunAlertPanel2(NSString *title,
                           NSString *msgFormat,
                           NSString *defaultButton,
                           NSString *alternateButton,
                           NSString *otherButton);

extern NSInteger NSRunInformationalAlertPanel2(NSString *title,
                           NSString *msgFormat,
                           NSString *defaultButton,
                           NSString *alternateButton,
                           NSString *otherButton);

extern NSInteger NSRunCriticalAlertPanel2(NSString *title,
                           NSString *msgFormat,
                           NSString *defaultButton,
                           NSString *alternateButton,
                           NSString *otherButton);