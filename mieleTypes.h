//
//  mieleTypes.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 2 Oct 2019
//  Copyright © 2019 bettar. All rights reserved.
//  License GPLv3.0 -- see License File
//

#ifndef mieleTypes_h
#define mieleTypes_h

#import <AppKit/AppKit.h>

typedef NS_ENUM(NSUInteger, EngineType) {
    ENGINE_CPU = 0,             // RAY CAST
    ENGINE_GPU_OPEN_GL = 1,
    ENGINE_BOTH = 2             // For Stereo, see also MAPPERMODEVR
};

#define MPR2DViewsPosition_KEY              @"MPR2DViewsPosition"
typedef NS_ENUM(NSUInteger, MPRLayoutType) {
    MPR_LAYOUT_2_1 = 0,                 // Portrait != Landscape (default)
    MPR_LAYOUT_VERTICAL_STACK = 1,      // 3 horizontal splits
    MPR_LAYOUT_HORIZONTAL_STACK = 2     // 3 vertical splits
};

#define EXPORTMATRIXFOR3D_KEY               @"EXPORTMATRIXFOR3D"
typedef NS_ENUM(NSInteger, ExportMatrixFor3DType) {
    EXPORT_SIZE_CURRENT = 0,
    EXPORT_SIZE_512 = 1,
    EXPORT_SIZE_768 = 2
};

#define UseDelaunayFor3DRoi_KEY             @"UseDelaunayFor3DRoi"
typedef NS_ENUM(NSInteger, UseDelaunayFor3DRoiType) {
    ROI_VOLUME_POWER_CRUST = 0,
    ROI_VOLUME_DELAUNAY = 1,
    ROI_VOLUME_ISO_CONTOUR = 2  // default
};

#define ListenerCompressionSettings_KEY     @"ListenerCompressionSettings"
// See also tags in Preferences, Listener panel
typedef NS_ENUM(NSInteger, ListenerCompressionSettingsType) {
    LISTENER_COMPRESSION_DONT_MODIFY = 0, // default
    LISTENER_COMPRESSION_DECOMPRESS = 1,
    LISTENER_COMPRESSION_COMPRESS = 2
};

// See also tags in Viewer.xib Orientation Matrix
typedef NS_ENUM(NSInteger, OrientationToolType) {
    ORIENTATION_UNDEFINED = -1,
    ORIENTATION_AXIAL = 0,
    ORIENTATION_CORONAL = 1,
    ORIENTATION_SAGITTAL = 2
};

#endif /* mieleTypes_h */
