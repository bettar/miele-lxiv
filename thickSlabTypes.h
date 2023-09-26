//  thickSLabTypes.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 13 Sep 2023
//  Copyright © 2023 bettar. All rights reserved.
//  License GPLv3.0 -- see License File
//

#ifndef thickSLabTypes_h
#define thickSLabTypes_h

#import <AppKit/AppKit.h>

// Originally in CPRProjectionOperation.h
// Note: These values must match taags in MPR.xib and CPR.xib
typedef NS_ENUM(NSInteger, MPRProjectionMode) {
    MPR_PROJECTION_MODE_VR = 0,   // don't use this in CPR, it's implemented only in MPR
    MPR_PROJECTION_MODE_MIP = 1,
    MPR_PROJECTION_MODE_MIN_IP = 2,
    MPR_PROJECTION_MODE_MEAN = 3,
    MPR_PROJECTION_MODE_ADDITIVE = 4,
    
    MPR_PROJECTION_MODE_NONE = 0xFFFFFF
};

#endif /* thickSLabTypes_h */
