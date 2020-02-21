//
//  cprTypes.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 24 Nov 2019
//  Copyright © 2019 bettar. All rights reserved.
//  License GPLv3.0 -- see License File
//

#ifndef cprTypes_h
#define cprTypes_h

#import <AppKit/AppKit.h>

// originally in CPRTransverseView.h
typedef NS_ENUM(NSInteger, CPRTransverseViewSection) {
    CPR_TRANSVERSE_VIEW_SECTION_NONE = -1,
    CPR_TRANSVERSE_VIEW_SECTION_CENTER = 0,
    CPR_TRANSVERSE_VIEW_SECTION_LEFT,
    CPR_TRANSVERSE_VIEW_SECTION_RIGHT
};

// originally in CPRProjectionOperation.h
typedef NS_ENUM(NSInteger, CPRProjectionMode) {
    CPR_PROJECTION_MODE_VR = 0,   // don't use this, it is not implemented
    CPR_PROJECTION_MODE_MIP = 1,
    CPR_PROJECTION_MODE_MIN_IP = 2,
    CPR_PROJECTION_MODE_MEAN = 3,
    CPR_PROJECTION_MODE_ADDITIVE = 4,
    
    CPR_PROJECTION_MODE_NONE = 0xFFFFFF
};

typedef NS_ENUM(NSInteger, CPRLayoutType) {
    NormalPosition = 0,
    HorizontalPosition = 1,
    VerticalPosition = 2
};

// Also used for reformation style
typedef NS_ENUM(NSInteger, CPRType) {
    CPRStraightenedType = 0,
    CPRStretchedType = 1
};

typedef NS_ENUM(NSInteger, CPRExportImageFormat) {
    CPR8BitRGBExportImageFormat = 0,
    CPR16BitExportImageFormat = 1
};

typedef NS_ENUM(NSInteger, CPRExportSequenceType) {
    CPRCurrentOnlyExportSequenceType = 0,
    CPRSeriesExportSequenceType = 1
};

typedef NS_ENUM(NSInteger, CPRExportSeriesType) {
    CPRRotationExportSeriesType = 0,
    CPRSlabExportSeriesType = 1,
    CPRTransverseViewsExportSeriesType = 2
};

typedef NS_ENUM(NSInteger, CPRExportRotationSpan) {
    CPR180ExportRotationSpan = 0,
    CPR360ExportRotationSpan = 1
};

#endif /* cprTypes_h */
