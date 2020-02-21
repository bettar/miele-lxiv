//
//  options.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 17 Nov 2014.
//  Copyright (c) 2014-2018 Miele-LXIV Team. All rights reserved.
//  License GPLv3.0 -- see License File
//

#ifndef OPTIONS_H_INCLUDED
#define OPTIONS_H_INCLUDED

#define MALLOC_ERROR_MESSAGE    "NOT ENOUGH MEMORY"

// /////////////////////////////////////////////////////////////////////////////
/* If using this feature, also create your own Binaries/Icon/DefaultBanner.png
 */
//#define WITH_BANNER

// /////////////////////////////////////////////////////////////////////////////
//#define WITH_IMPORTANT_NOTICE

// /////////////////////////////////////////////////////////////////////////////
#define WITH_OS_VALIDATION

// /////////////////////////////////////////////////////////////////////////////
//#define WITH_RED_CAPTION

// /////////////////////////////////////////////////////////////////////////////
/* Useful settings for debugging: search the source files for
 *
 * [[NSUserDefaults standardUserDefaults] boolForKey: @"verbose_dcmtkStoreScu"]
 *
 *  preprocessor macros:
 *      _STEREO_VISION_
 *      NONETWORKFUNCTIONS
 *      DEBUG_DCMTK_NETWORKING_VERBOSE
 *
 *  defines that get compiled:
 *      BUILTIN_DCMTK_SERVER
 *      DCMDEBUG
 */
#endif
