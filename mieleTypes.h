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

typedef NS_ENUM(NSInteger, BlendingType) {
    BLENDING_PLUGINS_METHOD = -1,
    BLENDING_UNDEFINED = 0,
    BLENDING_IMAGE_FUSION = 1,
    BLENDING_IMAGE_SUBTRACTION = 2,
    BLENDING_IMAGE_MULTIPLICATION = 3,
    BLENDING_RGB_COMPOSITION_1 = 4,
    BLENDING_RGB_COMPOSITION_2 = 5,
    BLENDING_RGB_COMPOSITION_3 = 6,
    BLENDING_2D_REGISTRATION = 7,
    BLENDING_3D_REGISTRATION = 8,
    BLENDING_LL_FILTER = 9,
    BLENDING_COPY_ROIS = 10,
    BLENDING_RESAMPLE_RESCALE = 11,
    BLENDING_RESAMPLE_NO_RESCALE = 12
};

#define VRDefaultViewSize_KEY     @"VRDefaultViewSize"
// See also tags in Preferences, 3D
typedef NS_ENUM(NSInteger, VRDefaultViewSizeType) {
    VR_VIEW_SIZE_SQUARE_FULL_SCREEN = 0, // default
    VR_VIEW_SIZE_FULL_SCREEN = 1,
    VR_VIEW_SIZE_512x512 = 2,
    VR_VIEW_SIZE_768x768 = 3
};

#define CD_MOUNT_KEY     @"MOUNT"
// See also tags in Preferences, CD
typedef NS_ENUM(NSInteger, CDMountModeType) {
    CD_MODE_ASK_USER = -1, // ask the user
    CD_MODE_SHOW_AS_SEPARATE_SOURCE = 0, // show disc content as a separate source
    CD_MODE_COPY_TO_DB = 1, // copy all its contents to the DB
    CD_MODE_IGNORE = 2 // ignore it
};

#define WINDOWSIZEVIEWER_KEY     @"WINDOWSIZEVIEWER"
// See also tags in Preferences, Viewer, Window Size
typedef NS_ENUM(NSInteger, WindowSizeViewerType) {
    WINDOW_SIZE_FULL_SCREEN = 0,
    WINDOW_SIZE_100_RES = 1,
    WINDOW_SIZE_150_RES = 2,
    WINDOW_SIZE_200_RES = 3
};

#define COPYDATABASEMODE_KEY     @"COPYDATABASEMODE"
// See also tags in Preferences, Database, File Management
typedef NS_ENUM(NSInteger, CopyDBModeType) {
    COPY_DB_ALWAYS = 0,
    COPY_DB_CD_ONLY = 1,            // Unused. Tag 1 "if on CD", disappeared after new CD/DVD import system
    COPY_DB_NOT_MAIN_DRIVE = 2,     // if files aren't located on HD
    COPY_DB_ASK_USER = 3            // ask the user
};

#define ANNOTATIONS_KEY         @"ANNOTATIONS"
typedef NS_ENUM(NSInteger, AnnotationsType) {
    ANNOTATIONS_NONE = 0,
    ANNOTATIONS_GRAPHICS,
    ANNOTATIONS_BASE,
    ANNOTATIONS_FULL,
    ANNOTATIONS_PLUGIN_ONLY  // is it actually possible to set this type ?
};

#define CLUTBARS_KEY            @"CLUTBARS"
typedef NS_ENUM(NSInteger, ClutBarsType) {
    CLUT_BAR_HIDE = 0,
    CLUT_BAR_ORIGIN,
    CLUT_BAR_FUSED,
    CLUT_BAR_BOTH
};

#define DEFAULT_MODE_FOR_NON_VOLUMIC_SERIES_KEY     @"DefaultModeForNonVolumicSeries"
// See also tags in MainMenu, 2D viewer
typedef NS_ENUM(NSInteger, SynchroType) {
    SYNCHRO_OFF = 0,            // Off
    SYNCHRO_ID_ABS = 1,         // Slice ID absolute
    SYNCHRO_ID_REL = 2,         // Slice ID relative
    SYNCHRO_POSITION_ABS = 3,   // Slice position absolute (Based on Location)
    SYNCHRO_ID_ABS_RATIO = 4    // Slice ID absolute ratio
};

typedef NS_ENUM(NSInteger, Intersection3DType) {
    INTERSECT_3D_NONE = 0,          // disjoint (no intersection)
    INTERSECT_3D_ONE_POINT,         // intersection in the unique point *I0
    INTERSECT_3D_SEGMENT_ON_PLANE   // the segment lies in the plane
};

typedef NS_ENUM(NSInteger, FontType) {
    FONT_TYPE_2D_VIEW = 0,
    FONT_TYPE_PREVIEW = 1,
    FONT_TYPE_ROI = 2,

    FONT_TYPE_INVALID
};

#endif /* mieleTypes_h */
